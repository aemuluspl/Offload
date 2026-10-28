import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/note.dart';
import '../theme/offload_theme.dart';

/// Плоский граф заметок в духе Obsidian: узлы расталкиваются, связи
/// притягивают, а кнопка воспроизведения показывает историю создания заметок.
class GraphOrb extends StatefulWidget {
  const GraphOrb({
    super.key,
    required this.notes,
    required this.nodeScale,
    required this.activeTag,
    required this.onTagSelected,
    this.onNotice,
    this.onExpand,
    this.onClose,
    this.compact = false,
    this.showChrome = true,
    this.pulseToken = 0,
  });

  final List<Note> notes;
  final double nodeScale;
  final String? activeTag;
  final ValueChanged<String?> onTagSelected;
  final ValueChanged<String>? onNotice;
  final VoidCallback? onExpand;
  final VoidCallback? onClose;
  final bool compact;
  final bool showChrome;
  final int pulseToken;

  @override
  State<GraphOrb> createState() => _GraphOrbState();
}

class _GraphOrbState extends State<GraphOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Duration _clock = Duration.zero;

  Size _canvasSize = Size.zero;
  final List<GraphNode> _nodes = [];
  final List<GraphLink> _links = [];
  final List<GraphNode> _chronological = [];
  bool _pendingSync = true;

  double _alpha = 1;
  double _zoom = 1;
  Offset _pan = Offset.zero;

  double _gestureStartZoom = 1;
  GraphNode? _dragNode;
  bool _gestureActive = false;

  bool _timelinePlaying = false;
  int _revealed = 0;
  int _timelineTotal = 0;
  Duration _timelineStart = Duration.zero;
  Duration _timelineDuration = Duration.zero;
  final Map<int, Duration> _births = {};

  double get _minDim => math.min(_canvasSize.width, _canvasSize.height);

  Offset get _center =>
      Offset(_canvasSize.width / 2, _canvasSize.height / 2);

  int? get _visibleCount => _timelinePlaying ? _revealed : null;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ensureTicker();
  }

  @override
  void didUpdateWidget(covariant GraphOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.notes, oldWidget.notes) ||
        widget.pulseToken != oldWidget.pulseToken ||
        widget.nodeScale != oldWidget.nodeScale) {
      _pendingSync = true;
      _alpha = 1;
      if (_timelinePlaying) {
        _timelinePlaying = false;
        _revealed = 0;
        _births.clear();
      }
      _ensureTicker();
    }
    if (widget.activeTag != oldWidget.activeTag) {
      for (final node in _nodes) {
        node.selected = widget.activeTag != null &&
            node.note.tags.contains(widget.activeTag);
      }
      for (final link in _links) {
        link.highlighted = widget.activeTag != null &&
            link.sharedTags.contains(widget.activeTag);
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _ensureTicker() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final raw = (elapsed - _lastTick).inMicroseconds;
    _lastTick = elapsed;
    final micros = raw.clamp(0, 50000);
    if (micros <= 0) {
      return;
    }
    final dt = micros / 1000000.0;
    _clock += Duration(microseconds: micros);

    _stepPhysics(dt);
    _stepTimeline();

    if (!_timelinePlaying &&
        !_gestureActive &&
        _dragNode == null &&
        _alpha < 0.006) {
      _alpha = 0;
      _ticker.stop();
      _lastTick = Duration.zero;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _stepPhysics(double dt) {
    if (_nodes.isEmpty || _canvasSize.isEmpty) {
      _alpha *= math.pow(0.9, dt * 60).toDouble();
      if (_alpha < 0.004) {
        _alpha = 0;
      }
      return;
    }
    final frame = (dt * 60).clamp(0.25, 2.0);
    var strength = _alpha * frame;
    if (_timelinePlaying) {
      strength = math.max(strength, 0.35 * frame);
    }
    if (strength <= 0) {
      return;
    }

    // Мягкое притяжение к центру, чтобы граф не уползал за пределы кадра.
    final centerPull = 0.0022 * strength;
    for (final node in _nodes) {
      node.position *= 1 - centerPull;
    }

    // Расталкивание только соседних ячеек: O(n) на больших списках.
    const cellSize = 160.0;
    final cells = <int, List<GraphNode>>{};
    for (final node in _nodes) {
      final cx = (node.position.dx / cellSize).floor();
      final cy = (node.position.dy / cellSize).floor();
      cells.putIfAbsent(_cellKey(cx, cy), () => []).add(node);
    }
    for (final node in _nodes) {
      final cx = (node.position.dx / cellSize).floor();
      final cy = (node.position.dy / cellSize).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final bucket = cells[_cellKey(cx + dx, cy + dy)];
          if (bucket == null) {
            continue;
          }
          for (final other in bucket) {
            if (other.index <= node.index) {
              continue;
            }
            _repel(node, other, strength);
          }
        }
      }
    }

    for (final link in _links) {
      _pull(link, strength);
    }

    final halfW = _canvasSize.width / 2 + 80;
    final halfH = _canvasSize.height / 2 + 80;
    for (final node in _nodes) {
      node.position = Offset(
        node.position.dx.clamp(-halfW, halfW),
        node.position.dy.clamp(-halfH, halfH),
      );
    }

    _alpha *= math.pow(0.972, frame).toDouble();
    if (_alpha < 0.004) {
      _alpha = 0;
    }
  }

  void _repel(GraphNode a, GraphNode b, double strength) {
    var delta = a.position - b.position;
    var distance = delta.distance;
    if (distance < 0.001) {
      final angle = (a.note.id * 2.399963) % (math.pi * 2);
      delta = Offset(math.cos(angle), math.sin(angle));
      distance = 0.001;
    }
    final unit = delta / distance;
    final minimum = a.radius + b.radius + 9;
    if (distance < minimum) {
      final push = (minimum - distance) * 0.34 * strength;
      a.position += unit * push * 0.5;
      b.position -= unit * push * 0.5;
    } else if (distance < 150) {
      final push = (150 - distance) / 150 * 0.42 * strength;
      a.position += unit * push;
      b.position -= unit * push;
    }
  }

  void _pull(GraphLink link, double strength) {
    final delta = link.target.position - link.source.position;
    final distance = delta.distance;
    if (distance < 0.001) {
      return;
    }
    final desired = 52 + link.source.radius + link.target.radius;
    final difference = distance - desired;
    final unit = delta / distance;
    if (difference > 0) {
      final pull = difference * 0.014 * strength;
      link.source.position += unit * pull;
      link.target.position -= unit * pull;
    } else {
      final push = -difference * 0.022 * strength;
      link.source.position -= unit * push;
      link.target.position += unit * push;
    }
  }

  void _stepTimeline() {
    if (!_timelinePlaying) {
      return;
    }
    _alpha = math.max(_alpha, 0.45);
    final totalMicros = _timelineDuration.inMicroseconds;
    if (totalMicros <= 0 || _timelineTotal == 0) {
      _timelinePlaying = false;
      return;
    }
    final passed = (_clock - _timelineStart).inMicroseconds;
    final progress = (passed / totalMicros).clamp(0.0, 1.0);
    final target = (progress * _timelineTotal).ceil().clamp(0, _timelineTotal);
    if (target > _revealed) {
      for (var index = _revealed; index < target; index++) {
        if (index < _chronological.length) {
          _births[_chronological[index].note.id] = _clock;
        }
      }
      _revealed = target;
      _alpha = 1;
    }
    if (progress >= 1) {
      _timelinePlaying = false;
      _revealed = _timelineTotal;
      _alpha = 1;
    }
  }

  int _cellKey(int x, int y) => ((x & 0xffff) << 16) | (y & 0xffff);

  void _syncNotes() {
    _pendingSync = false;
    if (_canvasSize.isEmpty) {
      return;
    }
    final previous = <int, GraphNode>{
      for (final node in _nodes) node.note.id: node,
    };
    final wasEmpty = previous.isEmpty;

    final sorted = [...widget.notes]..sort((a, b) {
        final byDate = a.createdAt.compareTo(b.createdAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    final chronologicalIndex = <int, int>{
      for (var index = 0; index < sorted.length; index++) sorted[index].id: index,
    };

    final nextNodes = <GraphNode>[];
    final maxRadius = _minDim * 0.4;
    final count = math.max(1, sorted.length);
    for (final note in widget.notes) {
      final existing = previous[note.id];
      if (existing != null) {
        existing.note = note;
        nextNodes.add(existing);
        continue;
      }
      final chrono = chronologicalIndex[note.id] ?? 0;
      late Offset position;
      if (wasEmpty) {
        final angle = chrono * 2.399963229728653;
        final radius = 14 + math.sqrt((chrono + 0.5) / count) * maxRadius;
        position = Offset(math.cos(angle), math.sin(angle)) * radius;
      } else {
        final angle = (note.id * 0.6180339887) % (math.pi * 2);
        final radius = 12.0 + (note.id % 6) * 6.0;
        position = Offset(math.cos(angle), math.sin(angle)) * radius;
      }
      nextNodes.add(GraphNode(note: note, position: position, radius: 5));
    }

    final nextChronological = [...nextNodes]..sort(
        (a, b) => (chronologicalIndex[a.note.id] ?? 0)
            .compareTo(chronologicalIndex[b.note.id] ?? 0),
      );

    final byTag = <String, List<int>>{};
    for (var index = 0; index < nextNodes.length; index++) {
      for (final tag in nextNodes[index].note.tags) {
        byTag.putIfAbsent(tag, () => []).add(index);
      }
    }
    final pairTags = <String, List<String>>{};
    for (final entry in byTag.entries) {
      final list = entry.value;
      if (list.length < 2) {
        continue;
      }
      if (list.length <= 30) {
        for (var first = 0; first < list.length; first++) {
          for (var second = first + 1; second < list.length; second++) {
            _addPair(pairTags, list[first], list[second], entry.key);
          }
        }
      } else {
        for (var index = 1; index < list.length; index++) {
          _addPair(pairTags, list[index - 1], list[index], entry.key);
        }
      }
    }

    final degree = List<int>.filled(nextNodes.length, 0);
    final nextLinks = <GraphLink>[];
    for (final entry in pairTags.entries) {
      final separator = entry.key.indexOf(':');
      final first = int.parse(entry.key.substring(0, separator));
      final second = int.parse(entry.key.substring(separator + 1));
      degree[first]++;
      degree[second]++;
      nextLinks.add(
        GraphLink(
          source: nextNodes[first],
          target: nextNodes[second],
          sharedTags: entry.value,
          highlighted: widget.activeTag != null &&
              entry.value.contains(widget.activeTag),
        ),
      );
    }

    for (var index = 0; index < nextNodes.length; index++) {
      final node = nextNodes[index];
      node.index = index;
      node.degree = degree[index];
      node.chronoIndex = chronologicalIndex[node.note.id] ?? index;
      node.radius =
          (4.6 + math.min(7.0, math.sqrt(degree[index]) * 2.1)) *
              widget.nodeScale.clamp(0.45, 2.2);
      node.selected = widget.activeTag != null &&
          node.note.tags.contains(widget.activeTag);
    }

    _nodes
      ..clear()
      ..addAll(nextNodes);
    _links
      ..clear()
      ..addAll(nextLinks);
    _chronological
      ..clear()
      ..addAll(nextChronological);
    _timelineTotal = _chronological.length;
    if (_revealed > _timelineTotal) {
      _revealed = _timelineTotal;
    }
  }

  void _addPair(
    Map<String, List<String>> pairs,
    int first,
    int second,
    String tag,
  ) {
    final low = math.min(first, second);
    final high = math.max(first, second);
    pairs.putIfAbsent('$low:$high', () => []).add(tag);
  }

  void _updateCanvasSize(Size size) {
    if (size == _canvasSize) {
      return;
    }
    final old = _canvasSize;
    _canvasSize = size;
    if (old.isEmpty) {
      _pendingSync = true;
      return;
    }
    final factor = math.min(size.width / old.width, size.height / old.height);
    for (final node in _nodes) {
      node.position *= factor;
    }
    _alpha = math.max(_alpha, 0.55);
    _ensureTicker();
  }

  GraphNode? _nodeAt(Offset localPosition) {
    if (_canvasSize.isEmpty) {
      return null;
    }
    final world =
        (localPosition - _center - _pan) / _zoom;
    final visible = _visibleCount;
    for (final node in _nodes.reversed) {
      if (visible != null && node.chronoIndex >= visible) {
        continue;
      }
      if ((world - node.position).distance <=
          node.radius + 9 / _zoom + 3) {
        return node;
      }
    }
    return null;
  }

  void _handleTap(Offset localPosition) {
    final node = _nodeAt(localPosition);
    if (node == null) {
      if (widget.activeTag != null) {
        widget.onTagSelected(null);
      }
      return;
    }
    if (node.note.tags.isEmpty) {
      widget.onNotice?.call('Добавьте #хэштег в заметку для связи');
      return;
    }
    final tag = node.note.tags.first;
    widget.onTagSelected(widget.activeTag == tag ? null : tag);
  }

  void _toggleTimeline() {
    if (_timelineTotal < 2) {
      widget.onNotice?.call('Нужно хотя бы две заметки');
      return;
    }
    if (_timelinePlaying) {
      _timelinePlaying = false;
      _revealed = 0;
      _births.clear();
      _alpha = 1;
    } else {
      _timelinePlaying = true;
      _revealed = 0;
      _births.clear();
      _timelineStart = _clock;
      final millis =
          (_timelineTotal * 150).clamp(2400, 15000).toInt();
      _timelineDuration = Duration(milliseconds: millis);
      _alpha = 0.85;
      widget.onNotice?.call(
        'История создания: $_timelineTotal '
        '${_plural(_timelineTotal, 'заметка', 'заметки', 'заметок')}',
      );
    }
    _ensureTicker();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(palette.radius);

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.graph,
          borderRadius: radius,
          border: Border.all(color: palette.border, width: 1.2),
        ),
        child: MouseRegion(
          cursor: _gestureActive
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              _gestureActive = true;
              _gestureStartZoom = _zoom;
              _dragNode = _nodeAt(details.localFocalPoint);
              _alpha = math.max(_alpha, 0.45);
              _ensureTicker();
            },
            onScaleUpdate: (details) {
              if (_dragNode != null) {
                _dragNode!.position =
                    (details.localFocalPoint - _center - _pan) / _zoom;
                _alpha = math.max(_alpha, 0.65);
                _ensureTicker();
                setState(() {});
                return;
              }
              if (details.pointerCount >= 2) {
                final focal = details.localFocalPoint;
                final worldBefore = (focal - _center - _pan) / _zoom;
                _zoom = (_gestureStartZoom * details.scale)
                    .clamp(0.55, 2.6)
                    .toDouble();
                _pan = focal - _center - worldBefore * _zoom;
              } else {
                _pan += details.focalPointDelta;
              }
              setState(() {});
            },
            onScaleEnd: (_) {
              _gestureActive = false;
              _dragNode = null;
              _alpha = math.max(_alpha, 0.5);
              _ensureTicker();
            },
            onTapUp: (details) => _handleTap(details.localPosition),
            onDoubleTap: () {
              setState(() {
                _zoom = 1;
                _pan = Offset.zero;
              });
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                _updateCanvasSize(
                  Size(constraints.maxWidth, constraints.maxHeight),
                );
                if (_pendingSync) {
                  _syncNotes();
                }
                final visible = _visibleCount;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _GraphPainter(
                        nodes: _nodes,
                        links: _links,
                        palette: palette,
                        compact: widget.compact,
                        zoom: _zoom,
                        pan: _pan,
                        visibleCount: visible,
                        hasFilter: widget.activeTag != null,
                        now: _clock,
                        births: _births,
                        timelinePlaying: _timelinePlaying,
                        timelineProgress: _timelineTotal == 0
                            ? 0
                            : _revealed / _timelineTotal,
                      ),
                    ),
                    if (widget.notes.isEmpty)
                      IgnorePointer(
                        child: Center(
                          child: Text(
                            'Добавьте первую мысль',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    if (widget.showChrome) ...[
                      Positioned(
                        left: 14,
                        top: 11,
                        child: IgnorePointer(
                          child: Text(
                            _timelinePlaying
                                ? '$_revealed / $_timelineTotal'
                                : _nodes.isEmpty
                                    ? 'нет узлов'
                                    : '${_nodes.length} '
                                        '${_plural(_nodes.length, 'узел', 'узла', 'узлов')}',
                            style: TextStyle(
                              color: palette.muted.withValues(alpha: 0.8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 8,
                        child: Row(
                          children: [
                            if (_timelineTotal > 1) ...[
                              _GraphChromeButton(
                                icon: _timelinePlaying
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                tooltip: _timelinePlaying
                                    ? 'Остановить историю'
                                    : 'История графа',
                                palette: palette,
                                onPressed: _toggleTimeline,
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (widget.onClose != null)
                              _GraphChromeButton(
                                icon: Icons.close_rounded,
                                tooltip: 'Свернуть граф',
                                palette: palette,
                                onPressed: widget.onClose!,
                              )
                            else if (widget.onExpand != null)
                              _GraphChromeButton(
                                icon: Icons.open_in_full_rounded,
                                tooltip: 'Развернуть граф',
                                palette: palette,
                                onPressed: widget.onExpand!,
                              ),
                          ],
                        ),
                      ),
                      if (widget.activeTag != null)
                        Positioned(
                          left: 12,
                          bottom: 14,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: palette.card.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(palette.radius),
                                border: Border.all(color: palette.border),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  text: 'Фильтр: ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: palette.muted,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: widget.activeTag,
                                      style: TextStyle(
                                        color: palette.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

String _plural(int value, String one, String few, String many) {
  final mod10 = value % 10;
  final mod100 = value % 100;
  if (mod10 == 1 && mod100 != 11) {
    return one;
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return few;
  }
  return many;
}

class _GraphChromeButton extends StatelessWidget {
  const _GraphChromeButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final OffloadPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.card.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 30,
            child: Icon(
              icon,
              size: 16,
              color: palette.text.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

class GraphNode {
  GraphNode({
    required this.note,
    required this.position,
    required this.radius,
  });

  Note note;
  Offset position;
  double radius;
  int degree = 0;
  int index = 0;
  int chronoIndex = 0;
  bool selected = false;

  List<String> get tags => note.tags;
}

class GraphLink {
  GraphLink({
    required this.source,
    required this.target,
    required this.sharedTags,
    required this.highlighted,
  });

  final GraphNode source;
  final GraphNode target;
  final List<String> sharedTags;
  bool highlighted;
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.nodes,
    required this.links,
    required this.palette,
    required this.compact,
    required this.zoom,
    required this.pan,
    required this.visibleCount,
    required this.hasFilter,
    required this.now,
    required this.births,
    required this.timelinePlaying,
    required this.timelineProgress,
  });

  final List<GraphNode> nodes;
  final List<GraphLink> links;
  final OffloadPalette palette;
  final bool compact;
  final double zoom;
  final Offset pan;
  final int? visibleCount;
  final bool hasFilter;
  final Duration now;
  final Map<int, Duration> births;
  final bool timelinePlaying;
  final double timelineProgress;

  bool _visible(GraphNode node) =>
      visibleCount == null || node.chronoIndex < visibleCount!;

  double _pop(GraphNode node) {
    final birth = births[node.note.id];
    if (birth == null) {
      return 1;
    }
    final progress =
        ((now - birth).inMicroseconds / 300000).clamp(0.0, 1.0).toDouble();
    if (progress >= 1) {
      return 1;
    }
    return Curves.easeOutBack.transform(progress);
  }

  Offset _screen(Offset world, Size size) {
    return Offset(
      size.width / 2 + pan.dx + world.dx * zoom,
      size.height / 2 + pan.dy + world.dy * zoom,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final background = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(palette.graph, palette.text, 0.035)!,
          palette.graph,
        ],
        stops: const [0, 0.9],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final dotPaint = Paint()
      ..color = palette.graphGrid.withValues(alpha: 0.85);
    const spacing = 27.0;
    final startX =
        ((size.width / 2 + pan.dx) % spacing + spacing) % spacing;
    final startY =
        ((size.height / 2 + pan.dy) % spacing + spacing) % spacing;
    for (var x = startX; x < size.width; x += spacing) {
      for (var y = startY; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.75, dotPaint);
      }
    }

    canvas.save();
    canvas.translate(size.width / 2 + pan.dx, size.height / 2 + pan.dy);
    canvas.scale(zoom);

    for (final link in links) {
      if (!_visible(link.source) || !_visible(link.target)) {
        continue;
      }
      final highlight = link.highlighted;
      final opacity = hasFilter && !highlight
          ? 0.1
          : highlight
              ? 0.72
              : 0.42;
      final paint = Paint()
        ..strokeWidth = (highlight ? 1.9 : 1.25) / zoom
        ..strokeCap = StrokeCap.round
        ..color = (highlight ? palette.accent : palette.graphLine)
            .withValues(alpha: opacity);
      canvas.drawLine(
        link.source.position,
        link.target.position,
        paint,
      );
    }

    final ordered = [...nodes]..sort((a, b) => b.radius.compareTo(a.radius));
    final nodeBase = palette.graph.computeLuminance() > 0.5
        ? const Color(0xFF404040)
        : const Color(0xFFD6D6D6);
    for (final node in ordered) {
      if (!_visible(node)) {
        continue;
      }
      final pop = _pop(node);
      if (pop <= 0.02) {
        continue;
      }
      final radius = math.max(1.5, node.radius * pop);
      final dimmed = hasFilter && !node.selected;
      final color = node.selected ? palette.accent : nodeBase;
      final alpha = dimmed ? 0.32 : 1.0;

      if (node.selected) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 / zoom
          ..color = palette.accent.withValues(alpha: 0.28);
        canvas.drawCircle(
          node.position,
          radius + 4.5 / zoom,
          ring,
        );
      }

      final glow = Paint()
        ..color = color.withValues(alpha: alpha * 0.32)
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          node.selected ? 7 : 3.5,
        );
      canvas.drawCircle(node.position, radius * 1.55, glow);

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: alpha);
      canvas.drawCircle(node.position, radius, fill);

      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 / zoom
        ..color = palette.graph.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(node.position, radius, border);
    }

    canvas.restore();

    if (!compact) {
      _paintLabels(canvas, size);
    }

    if (timelinePlaying) {
      final y = size.height - 3;
      final track = Paint()
        ..color = palette.graphLine.withValues(alpha: 0.14)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), track);
      final active = Paint()
        ..color = palette.accent
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(10, y),
        Offset(10 + (size.width - 20) * timelineProgress, y),
        active,
      );
    }
  }

  void _paintLabels(Canvas canvas, Size size) {
    for (final node in nodes) {
      if (!_visible(node) || _pop(node) < 0.55) {
        continue;
      }
      if (nodes.length > 80 && !node.selected && node.degree < 3) {
        continue;
      }
      final point = _screen(node.position, size);
      final radius = node.radius * zoom * _pop(node);
      if (point.dx < -80 ||
          point.dx > size.width + 80 ||
          point.dy < -40 ||
          point.dy > size.height + 40) {
        continue;
      }
      final style = TextStyle(
        fontFamily: 'Inter',
        fontSize: node.selected ? 11.5 : 10.5,
        fontWeight: node.selected ? FontWeight.w600 : FontWeight.w500,
        color: node.selected
            ? palette.accent
            : palette.muted.withValues(alpha: 0.92),
      );
      final painter = TextPainter(
        text: TextSpan(text: node.note.graphLabel, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 138);
      var x = point.dx - painter.width / 2;
      x = x.clamp(5.0, math.max(5.0, size.width - painter.width - 5));
      var y = point.dy + radius + 4;
      if (y + painter.height > size.height - 6) {
        y = point.dy - radius - painter.height - 3;
      }
      final shadow = TextPainter(
        text: TextSpan(
          text: node.note.graphLabel,
          style: style.copyWith(
            color: palette.graph,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 138);
      shadow.paint(canvas, Offset(x, y + 0.8));
      painter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return true;
  }
}
