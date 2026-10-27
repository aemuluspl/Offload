import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.isDark = true,
    this.nodeScale = 1.0,
    this.navSpeedMs = 180,
  });

  final bool isDark;
  final double nodeScale;
  final double navSpeedMs;

  AppSettings copyWith({
    bool? isDark,
    double? nodeScale,
    double? navSpeedMs,
  }) {
    return AppSettings(
      isDark: isDark ?? this.isDark,
      nodeScale: nodeScale ?? this.nodeScale,
      navSpeedMs: navSpeedMs ?? this.navSpeedMs,
    );
  }
}
