import 'package:flutter/services.dart';

bool _fullscreen = false;

/// Переключает полноэкранный режим на телефоне: скрывает/показывает строку
/// состояния и панель навигации. Никаких браузерных API — только Android.
Future<bool> toggleFullscreen() async {
  _fullscreen = !_fullscreen;
  await SystemChrome.setEnabledSystemUIMode(
    _fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
  );
  return _fullscreen;
}
