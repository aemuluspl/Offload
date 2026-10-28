import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsStore {
  static const _darkKey = 'offload.dark';
  static const _nodeScaleKey = 'offload.nodeScale';
  static const _navSpeedKey = 'offload.navSpeed';
  static const _cornerRadiusKey = 'offload.cornerRadius';
  static const _deepBlackKey = 'offload.deepBlack';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      isDark: prefs.getBool(_darkKey) ?? true,
      nodeScale:
          (prefs.getDouble(_nodeScaleKey) ?? 1.0).clamp(0.5, 2.2).toDouble(),
      navSpeedMs:
          (prefs.getDouble(_navSpeedKey) ?? 180).clamp(60, 500).toDouble(),
      cornerRadius:
          (prefs.getDouble(_cornerRadiusKey) ?? 24).clamp(4, 40).toDouble(),
      deepBlack: prefs.getBool(_deepBlackKey) ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_darkKey, settings.isDark),
      prefs.setDouble(_nodeScaleKey, settings.nodeScale),
      prefs.setDouble(_navSpeedKey, settings.navSpeedMs),
      prefs.setDouble(_cornerRadiusKey, settings.cornerRadius),
      prefs.setBool(_deepBlackKey, settings.deepBlack),
    ]);
  }
}
