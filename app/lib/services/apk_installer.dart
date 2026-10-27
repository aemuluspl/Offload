import 'package:flutter/services.dart';

/// Версия приложения, которую видит Android.
class AppVersion {
  const AppVersion({required this.version, required this.build});

  final String version;
  final int build;
}

/// Мост к Android: чтение версии и запуск системного установщика APK.
///
/// Тихая установка в Android запрещена — система всегда показывает экран
/// подтверждения, поэтому здесь только открывается штатный установщик.
class ApkInstaller {
  static const MethodChannel _channel = MethodChannel('offload/updater');

  static Future<AppVersion> appVersion() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('appVersion');
    return AppVersion(
      version: result?['version'] as String? ?? '0.0.0',
      build: (result?['build'] as num?)?.toInt() ?? 0,
    );
  }

  /// Разрешена ли установка из Offload (Android 8+).
  static Future<bool> canInstall() async {
    return await _channel.invokeMethod<bool>('canInstall') ?? false;
  }

  /// Открывает системный экран «Установка неизвестных приложений».
  static Future<void> openInstallSettings() async {
    await _channel.invokeMethod<void>('openInstallSettings');
  }

  /// Открывает установщик для скачанного APK.
  static Future<void> install(String path) async {
    await _channel.invokeMethod<void>('installApk', <String, Object>{
      'path': path,
    });
  }
}
