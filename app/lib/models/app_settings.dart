import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.isDark = true,
    this.nodeScale = 1.0,
    this.dropHideSeconds = 2.5,
    this.navSpeedMs = 180,
  });

  final bool isDark;
  final double nodeScale;
  final double dropHideSeconds;
  final double navSpeedMs;

  AppSettings copyWith({
    bool? isDark,
    double? nodeScale,
    double? dropHideSeconds,
    double? navSpeedMs,
  }) {
    return AppSettings(
      isDark: isDark ?? this.isDark,
      nodeScale: nodeScale ?? this.nodeScale,
      dropHideSeconds: dropHideSeconds ?? this.dropHideSeconds,
      navSpeedMs: navSpeedMs ?? this.navSpeedMs,
    );
  }
}
