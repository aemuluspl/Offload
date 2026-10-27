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

  static const _height = 62.0;
  static const _cellSize = 46.0;
  static const _horizontalPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = Duration(milliseconds: animationMs.round());
    final light = palette.graph.computeLuminance() > 0.5;

    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: light ? 0.07 : 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / 5;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: cell * activeIndex + (cell - _cellSize) / 2,
                top: (_height - _cellSize) / 2,
                width: _cellSize,
                height: _cellSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.navIndicator,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: light ? 0.10 : 0.24,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _NavCell(
                      icon: Icons.description_outlined,
                      tooltip: 'Заметки',
                      active: activeIndex == 0,
                      duration: duration,
                      onTap: onNotes,
                    ),
                  ),
                  Expanded(
                    child: _NavCell(
                      icon: Icons.insert_chart_outlined_rounded,
                      tooltip: 'Аналитика',
                      active: activeIndex == 1,
                      duration: duration,
                      onTap: onStats,
                    ),
                  ),
                  Expanded(
                    child: _GraphNavCell(
                      active: activeIndex == 2,
                      duration: duration,
                      pulseToken: graphSpinToken,
                      onTap: onGraph,
                    ),
                  ),
                  Expanded(
                    child: _NavCell(
                      icon: Icons.show_chart_rounded,
                      tooltip: 'Динамика',
                      active: activeIndex == 3,
                      duration: duration,
                      onTap: onTrends,
                    ),
                  ),
                  Expanded(
                    child: _NavCell(
                      icon: Icons.settings_outlined,
                      tooltip: 'Настройки',
                      active: activeIndex == 4,
                      duration: duration,
                      onTap: onSettings,
                    ),
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

class _NavCell extends StatelessWidget {
  const _NavCell({
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
    return Center(
      child: Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: OffloadNavBar._cellSize,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: active ? 1 : 0),
                duration: duration,
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Center(
                    child: Icon(
                      icon,
                      size: 22,
                      color: Color.lerp(
                        palette.muted,
                        palette.navInk,
                        value,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphNavCell extends StatelessWidget {
  const _GraphNavCell({
    required this.active,
    required this.duration,
    required this.pulseToken,
    required this.onTap,
  });

  final bool active;
  final Duration duration;
  final int pulseToken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Tooltip(
        message: 'Граф',
        child: SizedBox.square(
          dimension: OffloadNavBar._cellSize,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: active ? 1 : 0),
                duration: duration,
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Center(
                    child: GraphNavIcon(
                      color: Color.lerp(
                        palette.muted,
                        palette.navInk,
                        value,
                      )!,
                      pulseToken: pulseToken,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Плоская иконка графа: узлы и связи без 3D-вращения.
class GraphNavIcon extends StatelessWidget {
  const GraphNavIcon({
    super.key,
    required this.color,
    required this.pulseToken,
  });

  final Color color;
  final int pulseToken;

  static const _nodes = [
    Offset(0.50, 0.50),
    Offset(0.20, 0.25),
    Offset(0.81, 0.27),
    Offset(0.23, 0.78),
    Offset(0.79, 0.76),
    Offset(0.52, 0.12),
  ];
  static const _edges = [
    [0, 1],
    [0, 2],
    [0, 3],
    [0, 4],
    [1, 5],
    [2, 5],
    [3, 4],
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 27,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(pulseToken),
        tween: Tween(begin: pulseToken == 0 ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return CustomPaint(
            painter: _GraphIconPainter(
              color: color,
              pulse: pulseToken == 0 ? 1 : value,
            ),
          );
        },
      ),
    );
  }
}

class _GraphIconPainter extends CustomPainter {
  _GraphIconPainter({required this.color, required this.pulse});

  final Color color;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height);
    final line = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    for (final edge in GraphNavIcon._edges) {
      final first = GraphNavIcon._nodes[edge[0]];
      final second = GraphNavIcon._nodes[edge[1]];
      canvas.drawLine(
        Offset(first.dx * scale, first.dy * scale),
        Offset(second.dx * scale, second.dy * scale),
        line,
      );
    }
    final fill = Paint()..color = color;
    for (var index = 0; index < GraphNavIcon._nodes.length; index++) {
      final node = GraphNavIcon._nodes[index];
      final wave = math.sin(
        (pulse * math.pi + index * 0.55).clamp(0.0, math.pi * 2),
      );
      final radius = 2.35 + (pulse < 1 ? wave * 0.55 : 0);
      canvas.drawCircle(
        Offset(node.dx * scale, node.dy * scale),
        math.max(1.6, radius),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pulse != pulse;
  }
}
