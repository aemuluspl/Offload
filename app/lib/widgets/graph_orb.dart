import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/note.dart';
import '../theme/offload_theme.dart';

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

  double _yaw = 0.32;
  double _pitch = 0.16;
  double _velocityYaw = 0.16;
  double _velocityPitch = 0.028;
  bool _dragging = false;

  Size _canvasSize = Size.zero;
  GraphScene _scene = GraphScene.empty;
  Offset? _lastDragPosition;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant GraphOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulseToken != oldWidget.pulseToken) {
      _velocityYaw = (math.Random().nextBool() ? 1 : -1) * 0.5;
      _velocityPitch = (math.Random().nextDouble() - 0.5) * 0.28;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final seconds =
        (elapsed - _lastTick).inMicroseconds.clamp(0, 40000) / 1000000.0;
    _lastTick = elapsed;
    if (seconds <= 0) {
      return;
    }

    if (!_dragging) {
      _yaw += _velocityYaw * seconds;
      _pitch =
          (_pitch + _velocityPitch * seconds).clamp(-1.18, 1.18).toDouble();
      final damping = math.pow(0.986, seconds * 60).toDouble();
      _velocityYaw *= damping;
      _velocityPitch *= damping;
      if (_velocityYaw.abs() < 0.13) {
        _velocityYaw += (0.13 - _velocityYaw.abs()) * 0.04;
      }
      if (_velocityPitch.abs() < 0.018) {
        _velocityPitch += (0.018 - _velocityPitch.abs()) * 0.03;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  GraphScene _buildScene() {
    if (_canvasSize.isEmpty) {
      return GraphScene.empty;
    }
    return GraphScene.build(
      notes: widget.notes,
      size: _canvasSize,
      yaw: _yaw,
      pitch: _pitch,
      nodeScale: widget.nodeScale,
      activeTag: widget.activeTag,
      compact: widget.compact,
    );
  }

  void _handleTap(Offset localPosition) {
    final node = _scene.hitTest(localPosition);
    if (node == null) {
      return;
    }
    if (node.tags.isEmpty) {
      widget.onNotice?.call('Добавьте #хэштег в заметку для связи');
      return;
    }
    final tag = node.tags.first;
    widget.onTagSelected(widget.activeTag == tag ? null : tag);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    _scene = _buildScene();
    final radius = widget.compact
        ? const BorderRadius.only(
            topLeft: Radius.circular(38),
            topRight: Radius.circular(38),
            bottomLeft: Radius.circular(48),
            bottomRight: Radius.circular(48),
          )
        : BorderRadius.circular(26);

    final chrome = widget.showChrome
        ? Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: Stack(
                children: [
                  Positioned(
                    left: 15,
                    top: 14,
                    child: IgnorePointer(
                      child: Text(
                        _scene.nodes.isEmpty
                            ? 'нет узлов'
                            : '${_scene.nodes.length} '
                                '${_plural(_scene.nodes.length, 'узел', 'узла', 'узлов')}',
                        style: TextStyle(
                          color: palette.muted.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onClose != null)
                    Positioned(
                      right: 11,
                      top: 10,
                      child: _GraphIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Свернуть граф',
                        onPressed: widget.onClose!,
                      ),
                    )
                  else if (widget.onExpand != null)
                    Positioned(
                      right: 11,
                      top: 10,
                      child: _GraphIconButton(
                        icon: Icons.open_in_full_rounded,
                        tooltip: 'Развернуть граф',
                        onPressed: widget.onExpand!,
                      ),
                    ),
                  if (widget.activeTag != null)
                    Positioned(
                      left: 14,
                      bottom: 12,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text.rich(
                            TextSpan(
                              text: 'Фильтр: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.72),
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
              ),
            ),
          )
        : const SizedBox.shrink();

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.graph,
          borderRadius: radius,
          border: Border.all(
            color: palette.border,
            width: 1.3,
          ),
        ),
        child: MouseRegion(
          cursor:
              _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              _dragging = true;
              _lastDragPosition = details.localPosition;
            },
            onPanUpdate: (details) {
              if (!_dragging) {
                return;
              }
              final previous = _lastDragPosition ?? details.localPosition;
              final dx = details.localPosition.dx - previous.dx;
              final dy = details.localPosition.dy - previous.dy;
              _lastDragPosition = details.localPosition;
              _yaw += dx * 0.009;
              _pitch = (_pitch - dy * 0.009).clamp(-1.18, 1.18).toDouble();
              _velocityYaw = dx * 0.09;
              _velocityPitch = -dy * 0.09;
            },
            onPanEnd: (_) {
              _dragging = false;
              _lastDragPosition = null;
            },
            onPanCancel: () {
              _dragging = false;
              _lastDragPosition = null;
            },
            onTapUp: (details) => _handleTap(details.localPosition),
            child: LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                _scene = _buildScene();
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _GraphPainter(
                        scene: _scene,
                        palette: palette,
                        compact: widget.compact,
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
                    chrome,
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

class _GraphIconButton extends StatelessWidget {
  const _GraphIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.24),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 32,
            child: Icon(
              icon,
              size: 16,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

class GraphScene {
  const GraphScene({
    required this.nodes,
    required this.links,
    required this.center,
    required this.sphereRadius,
  });

  static const empty = GraphScene(
    nodes: [],
    links: [],
    center: Offset.zero,
    sphereRadius: 0,
  );

  final List<GraphNode> nodes;
  final List<GraphLink> links;
  final Offset center;
  final double sphereRadius;

  GraphNode? hitTest(Offset position) {
    final sorted = [...nodes]..sort((a, b) => b.depth.compareTo(a.depth));
    for (final node in sorted) {
      if ((position - node.position).distance <= node.radius + 13) {
        return node;
      }
    }
    return null;
  }

  static GraphScene build({
    required List<Note> notes,
    required Size size,
    required double yaw,
    required double pitch,
    required double nodeScale,
    required String? activeTag,
    required bool compact,
  }) {
    if (size.isEmpty) {
      return empty;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final sphereRadius = math.min(size.width, size.height) * 0.34;
    const fov = 340.0;
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final count = notes.length;
    final goldenAngle = math.pi * (3 - math.sqrt(5));

    final nodes = <GraphNode>[];
    for (var index = 0; index < count; index++) {
      final note = notes[index];
      double x;
      double y;
      double z;
      if (count == 1) {
        x = 0;
        y = 0;
        z = 0;
      } else if (count == 2) {
        x = index == 0 ? -0.55 : 0.55;
        y = index == 0 ? -0.2 : 0.2;
        z = 0;
      } else {
        y = 1 - (index / (count - 1)) * 2;
        final radiusAtY = math.sqrt(math.max(0, 1 - y * y));
        final theta = goldenAngle * index;
        x = math.cos(theta) * radiusAtY;
        z = math.sin(theta) * radiusAtY;
      }

      final x1 = x * cosYaw + z * sinYaw;
      final z1 = -x * sinYaw + z * cosYaw;
      final y1 = y;
      final y2 = y1 * cosPitch - z1 * sinPitch;
      final z2 = y1 * sinPitch + z1 * cosPitch;

      final depth = z2 * sphereRadius;
      final perspective = fov / math.max(80, fov - depth);
      final position = Offset(
        center.dx + x1 * sphereRadius * perspective,
        center.dy + y2 * sphereRadius * perspective,
      );
      final isSelected = activeTag != null && note.tags.contains(activeTag);
      final baseRadius = note.tags.isEmpty ? 8.0 : 9.5;
      final radius = math.max(
        3.5,
        baseRadius * nodeScale * perspective * (isSelected ? 1.2 : 1.0),
      );
      nodes.add(
        GraphNode(
          note: note,
          position: position,
          depth: z2,
          radius: radius,
          scale: perspective,
          selected: isSelected,
        ),
      );
    }

    final links = <GraphLink>[];
    for (var first = 0; first < nodes.length; first++) {
      for (var second = first + 1; second < nodes.length; second++) {
        final firstNode = nodes[first];
        final secondNode = nodes[second];
        final shared = firstNode.note.tags
            .where(secondNode.note.tags.contains)
            .toList(growable: false);
        if (shared.isNotEmpty) {
          links.add(
            GraphLink(
              source: firstNode,
              target: secondNode,
              sharedTags: shared,
              highlighted: activeTag != null && shared.contains(activeTag),
            ),
          );
        }
      }
    }

    return GraphScene(
      nodes: nodes,
      links: links,
      center: center,
      sphereRadius: sphereRadius,
    );
  }
}

class GraphNode {
  const GraphNode({
    required this.note,
    required this.position,
    required this.depth,
    required this.radius,
    required this.scale,
    required this.selected,
  });

  final Note note;
  final Offset position;
  final double depth;
  final double radius;
  final double scale;
  final bool selected;

  List<String> get tags => note.tags;
}

class GraphLink {
  const GraphLink({
    required this.source,
    required this.target,
    required this.sharedTags,
    required this.highlighted,
  });

  final GraphNode source;
  final GraphNode target;
  final List<String> sharedTags;
  final bool highlighted;
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.scene,
    required this.palette,
    required this.compact,
  });

  final GraphScene scene;
  final OffloadPalette palette;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(palette.graph, palette.text, 0.045)!,
          palette.graph,
        ],
        stops: const [0, 0.85],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final center = scene.center;
    final sphereRadius = scene.sphereRadius;
    if (sphereRadius <= 0) {
      return;
    }

    final spherePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.graphGrid;
    canvas.drawCircle(center, sphereRadius, spherePaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = palette.graphGrid.withValues(alpha: 0.65);
    canvas.drawCircle(center, sphereRadius * 0.68, innerPaint);

    for (final link in scene.links) {
      final source = link.source;
      final target = link.target;
      final averageDepth = (source.depth + target.depth) / 2;
      final alpha = ((averageDepth + 1.2) / 2.4).clamp(0.12, 0.82).toDouble();
      final paint = Paint()
        ..strokeWidth =
            (link.highlighted ? 2.0 : 1.25) * (0.7 + source.scale * 0.3)
        ..strokeCap = StrokeCap.round
        ..color = link.highlighted
            ? palette.accent.withValues(alpha: alpha)
            : palette.graphLine.withValues(alpha: alpha * 0.62);
      canvas.drawLine(source.position, target.position, paint);

      if (!compact) {
        _paintLinkLabel(canvas, link, alpha);
      }
    }

    final sorted = [...scene.nodes]..sort((a, b) => a.depth.compareTo(b.depth));
    for (final node in sorted) {
      _paintNode(canvas, node);
    }
  }

  void _paintLinkLabel(Canvas canvas, GraphLink link, double alpha) {
    final middle = Offset(
      (link.source.position.dx + link.target.position.dx) / 2,
      (link.source.position.dy + link.target.position.dy) / 2 - 7,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: link.sharedTags.join(' '),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: palette.accent.withValues(alpha: alpha * 0.95),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      middle - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintNode(Canvas canvas, GraphNode node) {
    final depthAlpha = ((node.depth + 1.3) / 2.3).clamp(0.28, 1.0).toDouble();
    final customColor = _parseColor(node.note.color);
    final color = node.selected
        ? palette.accent
        : customColor ??
            (palette.graph.computeLuminance() > 0.5
                ? const Color(0xFF334155)
                : const Color(0xFFE4E4E7));

    final glow = Paint()
      ..color = color.withValues(alpha: depthAlpha * 0.45)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7);
    canvas.drawCircle(node.position, node.radius * 1.8, glow);

    final fill = Paint()
      ..color = color.withValues(alpha: depthAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(node.position, node.radius, fill);

    final border = Paint()
      ..color = (palette.graph.computeLuminance() > 0.5
              ? Colors.white
              : const Color(0xFF181A1F))
          .withValues(alpha: depthAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(node.position, node.radius, border);

    final label = node.note.graphLabel;
    final textStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: compact ? 8.5 : (node.selected ? 11.8 : 11.2),
      fontWeight: node.depth > 0 ? FontWeight.w600 : FontWeight.w500,
      color: node.selected ? palette.accent : customColor ?? palette.text,
    );
    final maxWidth = compact ? 86.0 : 150.0;
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final labelX = (node.position.dx - labelPainter.width / 2)
        .clamp(6.0, math.max(6.0, scene.center.dx * 2 - maxWidth - 6))
        .toDouble();
    final labelY = node.position.dy + node.radius + 4;
    final shadowPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: textStyle.copyWith(
          color: palette.graph,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    shadowPainter.paint(canvas, Offset(labelX, labelY));
    labelPainter.paint(canvas, Offset(labelX, labelY));
  }

  Color? _parseColor(String value) {
    final clean = value.replaceFirst('#', '');
    if (clean.length != 6) {
      return null;
    }
    final parsed = int.tryParse(clean, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(0xFF000000 | parsed);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return true;
  }
}
