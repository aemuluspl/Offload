/// Репозиторий GitHub, из релизов которого приложение берёт обновления.
///
/// Формат: `владелец/репозиторий`. Можно переопределить при сборке:
/// `--dart-define=UPDATE_REPO=user/offload`.
///
/// Пока значение пустое, кнопка «Проверить обновления» честно скажет, что
/// канал не настроен; на работу приложения это не влияет.
const String updateRepo = String.fromEnvironment(
  'UPDATE_REPO',
  defaultValue: 'aemuluspl/Offload',
);
