import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/offload_theme.dart';

class OffloadNavBar extends StatelessWidget {
  const OffloadNavBar({
    super.key,
    required this.activeIndex,
    required this.animationMs,
    required this.graphSpinToken,
    required this.onNotes,
    required this.onStats,
    required this.onGraph,
    required this.onTrends,
    required this.onSettings,
  });

  final int activeIndex;
  final double animationMs;
  final int graphSpinToken;
  final VoidCallback onNotes;
  final VoidCallback onStats;
  final VoidCallback onGraph;
  final VoidCallback onTrends;
  final VoidCallback onSettings;

  static const _height = 74.0;
  static const _buttonSize = 56.0;
  static const _horizontalPadding = 16.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = Duration(milliseconds: animationMs.round());

    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final step = (constraints.maxWidth - _buttonSize) / 4;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: step * activeIndex,
                top: (_height - _buttonSize) / 2,
                width: _buttonSize,
                height: _buttonSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.navIndicator,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: palette.navIndicator.withValues(alpha: 0.4),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(
                    icon: Icons.description_outlined,
                    tooltip: 'Заметки',
                    active: activeIndex == 0,
                    duration: duration,
                    onTap: onNotes,
                  ),
                  _NavButton(
                    icon: Icons.insert_chart_outlined_rounded,
                    tooltip: 'Аналитика',
                    active: activeIndex == 1,
                    duration: duration,
                    onTap: onStats,
                  ),
                  _CenterNavButton(
                    active: activeIndex == 2,
                    duration: duration,
                    spinToken: graphSpinToken,
                    onTap: onGraph,
                  ),
                  _NavButton(
                    icon: Icons.show_chart_rounded,
                    tooltip: 'Динамика',
                    active: activeIndex == 3,
                    duration: duration,
                    onTap: onTrends,
                  ),
                  _NavButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Настройки',
                    active: activeIndex == 4,
                    duration: duration,
                    onTap: onSettings,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.duration,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 56,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: active ? 1 : 0),
              duration: duration,
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Icon(
                  icon,
                  size: 23,
                  color: Color.lerp(palette.muted, palette.navInk, value),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterNavButton extends StatelessWidget {
  const _CenterNavButton({
    required this.active,
    required this.duration,
    required this.spinToken,
    required this.onTap,
  });

  final bool active;
  final Duration duration;
  final int spinToken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: 'Граф',
      child: SizedBox.square(
        dimension: 56,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: active ? 1 : 0),
              duration: duration,
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return GraphNavIcon(
                  color: Color.lerp(palette.muted, palette.navInk, value)!,
                  spinToken: spinToken,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class GraphNavIcon extends StatefulWidget {
  const GraphNavIcon({
    super.key,
    required this.color,
    required this.spinToken,
  });

  final Color color;
  final int spinToken;

  @override
  State<GraphNavIcon> createState() => _GraphNavIconState();
}

class _GraphNavIconState extends State<GraphNavIcon>
    with SingleTickerProviderStateMixin {
  static const _vertices = [
    _Vertex(0, 0, 0, 2.35),
    _Vertex(-6.2, -5.8, 3.2, 1.95),
    _Vertex(6.4, -4.8, -2.8, 1.95),
    _Vertex(-5.5, 5.8, -3.4, 1.95),
    _Vertex(5.2, 5.6, 3.8, 1.95),
    _Vertex(0.5, -7.2, -5.2, 1.65),
  ];
  static const _edges = [
    [0, 1],
    [0, 2],
    [0, 3],
    [0, 4],
    [0, 5],
    [1, 5],
    [2, 4],
    [1, 3],
  ];

  late final AnimationController _controller;
  double _yaw = 0.25;
  double _pitch = 0.2;
  double _roll = 0;
  double _startYaw = 0.25;
  double _startPitch = 0.2;
  double _startRoll = 0;
  double _endYaw = 0.25;
  double _endPitch = 0.2;
  double _endRoll = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        setState(() {
          _yaw = _startYaw + (_endYaw - _startYaw) * progress;
          _pitch = _startPitch + (_endPitch - _startPitch) * progress;
          _roll = _startRoll + (_endRoll - _startRoll) * progress;
        });
      });
  }

  @override
  void didUpdateWidget(covariant GraphNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinToken != oldWidget.spinToken) {
      _startYaw = _yaw;
      _startPitch = _pitch;
      _startRoll = _roll;
      final direction = widget.spinToken.isEven ? 1.0 : -1.0;
      _endYaw = _yaw + direction * (1.2 + (widget.spinToken % 4) * 0.12);
      _endPitch = _pitch + direction * 0.8;
      _endRoll = _roll + (widget.spinToken.isEven ? 0.32 : -0.32);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: CustomPaint(
        painter: _GraphIconPainter(
          color: widget.color,
          yaw: _yaw,
          pitch: _pitch,
          roll: _roll,
          vertices: _vertices,
          edges: _edges,
        ),
      ),
    );
  }
}

class _Vertex {
  const _Vertex(this.x, this.y, this.z, this.radius);

  final double x;
  final double y;
  final double z;
  final double radius;
}

class _ProjectedVertex {
  const _ProjectedVertex(this.x, this.y, this.depth, this.radius);

  final double x;
  final double y;
  final double depth;
  final double radius;
}

class _GraphIconPainter extends CustomPainter {
  _GraphIconPainter({
    required this.color,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.vertices,
    required this.edges,
  });

  final Color color;
  final double yaw;
  final double pitch;
  final double roll;
  final List<_Vertex> vertices;
  final List<List<int>> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 24;
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final cosRoll = math.cos(roll);
    final sinRoll = math.sin(roll);

    final projected = vertices.map((vertex) {
      final x1 = vertex.x * cosYaw + vertex.z * sinYaw;
      final z1 = -vertex.x * sinYaw + vertex.z * cosYaw;
      final y1 = vertex.y;
      final y2 = y1 * cosPitch - z1 * sinPitch;
      final z2 = y1 * sinPitch + z1 * cosPitch;
      final x2 = x1;
      final x3 = x2 * cosRoll - y2 * sinRoll;
      final y3 = x2 * sinRoll + y2 * cosRoll;
      final perspective = 26 / (26 - z2);
      return _ProjectedVertex(
        (12 + x3 * perspective) * scale,
        (12 + y3 * perspective) * scale,
        z2,
        math.max(1.2, vertex.radius * perspective * 0.92) * scale,
      );
    }).toList(growable: false);

    final edgePaint = Paint()
      ..strokeWidth = 1.75 * scale
      ..strokeCap = StrokeCap.round;
    for (final edge in edges) {
      final first = projected[edge[0]];
      final second = projected[edge[1]];
      final averageDepth = (first.depth + second.depth) / 2;
      final opacity = ((averageDepth + 8) / 13).clamp(0.35, 1.0).toDouble();
      edgePaint.color = color.withValues(alpha: opacity);
      canvas.drawLine(
        Offset(first.x, first.y),
        Offset(second.x, second.y),
        edgePaint,
      );
    }

    final sorted = [...projected]..sort((a, b) => a.depth.compareTo(b.depth));
    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (final vertex in sorted) {
      final opacity = ((vertex.depth + 8) / 12).clamp(0.45, 1.0).toDouble();
      nodePaint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(vertex.x, vertex.y),
        vertex.radius,
        nodePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphIconPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.roll != roll ||
        oldDelegate.color != color;
  }
}
