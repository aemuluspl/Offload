import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.isDark = true,
    this.nodeScale = 1.0,
    this.navSpeedMs = 180,
    this.cornerRadius = 24,
    this.deepBlack = false,
  });

  final bool isDark;
  final double nodeScale;
  final double navSpeedMs;

  /// Глобальный радиус скруглений интерфейса (4–40 px).
  final double cornerRadius;

  /// Чистый чёрный фон в тёмной теме.
  final bool deepBlack;

  AppSettings copyWith({
    bool? isDark,
    double? nodeScale,
    double? navSpeedMs,
    double? cornerRadius,
    bool? deepBlack,
  }) {
    return AppSettings(
      isDark: isDark ?? this.isDark,
      nodeScale: nodeScale ?? this.nodeScale,
      navSpeedMs: navSpeedMs ?? this.navSpeedMs,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      deepBlack: deepBlack ?? this.deepBlack,
    );
  }
}
