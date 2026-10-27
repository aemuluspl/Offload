# Сборка APK

Приложение полностью локальное: APK не требует сервера, компьютера или
интернета. Всё, что нужно для сборки — Flutter, JDK и Android SDK.

## 1. Что нужно на компьютере

| Инструмент | Зачем | Где взять |
|---|---|---|
| Flutter SDK | компилятор Dart и инструменты сборки | уже установлен: `C:\Users\Admin\flutter` |
| JDK 17+ | нужен Gradle и Android-плагину | входит в Android Studio или Temurin |
| Android SDK | платформы, build-tools, adb | через Android Studio или command-line tools |

Проверка:

```powershell
C:\Users\Admin\flutter\bin\flutter.bat doctor -v
```

В блоке `Android toolchain` должно быть `[√]`. Если SDK установлен вручную,
укажите путь:

```powershell
C:\Users\Admin\flutter\bin\flutter.bat config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
```

Лицензии принимаются один раз:

```powershell
C:\Users\Admin\flutter\bin\flutter.bat doctor --android-licenses
```

## 2. Сборка

```powershell
cd C:\Users\Admin\Desktop\Offload\app
C:\Users\Admin\flutter\bin\flutter.bat build apk --release
```

Результат: `app\build\app\outputs\flutter-apk\app-release.apk`.

Полезные варианты:

```powershell
# APK только под архитектуру телефона (меньше размер)
flutter build apk --release --split-per-abi

# отладочная сборка: быстрее, но крупнее и медленнее работает
flutter build apk --debug
```

Первая сборка скачивает Gradle и зависимости — 10–40 минут. Последующие
занимают 1–3 минуты.

## 3. Подпись release-APK

Ключи лежат в `app/android/` и в git не попадают:

| Файл | Назначение |
|---|---|
| `offload-release.jks` | действующий ключ для 1.0.2+ (RSA 4096, SHA-256) |
| `offload-release-1.0.1.jks` | старый ключ версии 1.0.1, только для архива |
| `key.properties` | пароли и путь к действующему ключу |

Пароль keystore и ключа хранится в `key.properties` и в резервном архиве
`Offload-signing-key-20261028-1.0.2.zip` на рабочем столе. **Пароль и файл
нельзя терять**: без них невозможно выпустить обновление поверх установленной
версии.

Почему это важно: Android не даст установить APK с другой подписью поверх
существующего приложения. Версия 1.0.2 подписана новым ключом, поэтому
установить её поверх 1.0.1 нельзя — сначала нужно удалить старую версию.
Дальше все релизы 1.0.2+ подписываются этим же ключом.

Заменить ключ на свой можно так:

```powershell
keytool -genkeypair -v -keystore offload-release.jks `
  -storetype PKCS12 -keyalg RSA -keysize 4096 -sigalg SHA256withRSA `
  -validity 10000 -alias offload
```

и указать новые значения в `key.properties`. Если файла `key.properties` нет,
сборка пройдёт на отладочной подписи — такой APK годится только для проверки.

## 4. Установка на телефон

По кабелю:

1. На телефоне: «О телефоне» → 7 раз по «Номер сборки» → «Для разработчиков» →
   «Отладка по USB».
2. Подключить кабель, подтвердить отпечаток компьютера.
3. `adb devices` — устройство в списке.
4. `adb install -r app\build\app\outputs\flutter-apk\app-release.apk`.

Без кабеля: скопировать APK на телефон (Telegram «Избранное», облако, USB) и
открыть файл; разрешить установку из этого источника.

## 5. Что важно знать

- Заметки работают без интернета. В манифесте есть `INTERNET` и
  `REQUEST_INSTALL_PACKAGES` — только для добровольной проверки обновлений и
  запуска системного установщика. В фоне приложение в сеть не ходит.
- Заметки хранятся в приватной папке приложения. Удаление приложения удаляет
  данные.
- `applicationId` сейчас `com.example.offload`. Для Google Play его нужно
  сменить на свой (например, `ru.имя.offload`) до первой публикации.

## 6. Публикация обновления

1. Поднимите версию в `app/pubspec.yaml`, например `1.0.2+3` (номер после `+`
   должен расти, иначе Android может отказаться ставить APK).
2. Соберите APK:
   ```powershell
   cd app
   flutter build apk --release
   ```
   Если репозиторий не прописан в `lib/update_config.dart`, передайте его:
   `flutter build apk --release --dart-define=UPDATE_REPO=владелец/offload`.
   Сейчас там указан `aemuluspl/Offload`.
3. На GitHub откройте **Releases → Draft a new release**.
4. Tag: `v1.0.2` (совпадает с версией из pubspec), прикрепите
   `app-release.apk` как asset, опишите изменения, опубликуйте.
5. На телефоне: Настройки → «Обновления» → «Скачать». Приложение увидит
   `v1.0.2`, скачает APK и откроет установщик.

Важно:

- Репозиторий должен быть **публичным** — приложение читает релизы без токена.
- APK в релизе должен быть один (или первый с расширением `.apk`).
- Все APK одной ветки подписываются одним ключом. Если ключ потерять, установить
  обновление поверх не получится — только удаление приложения вместе с заметками.
- 1.0.2 подписана новым ключом. Первая установка 1.0.2 требует удалить 1.0.1:
  `adb uninstall com.example.offload`.
- GitHub API без авторизации разрешает 60 запросов в час на IP. Ручной проверки
  это более чем достаточно.

## 7. Если что-то не собирается

| Симптом | Решение |
|---|---|
| `Unable to locate Android SDK` | `flutter config --android-sdk <путь>` или переменная `ANDROID_HOME` |
| `licenses not accepted` | `flutter doctor --android-licenses` |
| `SDK location not found` | создать `app/android/local.properties` со строкой `sdk.dir=C:\Users\Admin\AppData\Local\Android\Sdk` |
| `Unsupported class file major version` | JDK слишком старый: нужен 17+ |
| Сборка падает на скачивании Gradle | проверить интернет/прокси, повторить |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | удалить старую версию: `adb uninstall com.example.offload` |

## 8. Проверка без телефона

- `flutter test` — логика хранилища и модели.
- `flutter analyze` — статический анализ кода.
- `flutter build apk --debug` — проверка, что Android-сборка проходит.

Веб-версии у проекта нет: `web/` удалён, зависимость `web` убрана. Приложение
собирается только под Android.
