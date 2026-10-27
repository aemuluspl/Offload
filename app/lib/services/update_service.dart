import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../update_config.dart';
import '../utils/version.dart';
import 'apk_installer.dart';

/// Ошибка проверки или скачивания обновления. Текст можно показывать человеку.
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.sizeBytes,
  });

  final String version;
  final String notes;
  final String apkUrl;
  final int sizeBytes;
}

/// Проверка обновлений через GitHub Releases.
///
/// Сеть используется только по явному нажатию кнопки. Приложение остаётся
/// офлайновым: без интернета все заметки работают как обычно.
class UpdateService {
  UpdateService({String repo = updateRepo}) : repo = repo.trim();

  final String repo;

  bool get isConfigured =>
      RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repo);

  Uri get _latestReleaseUri =>
      Uri.https('api.github.com', '/repos/$repo/releases/latest');

  /// Возвращает информацию о новой версии или `null`, если обновлений нет.
  Future<UpdateInfo?> check() async {
    if (!isConfigured) {
      throw const UpdateException(
        'Канал обновлений не настроен. Укажи репозиторий при сборке.',
      );
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(_latestReleaseUri);
      request.headers.set(HttpHeaders.userAgentHeader, 'Offload-Android');
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );

      final response = await request.close().timeout(
            const Duration(seconds: 25),
          );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 25));

      switch (response.statusCode) {
        case 200:
          break;
        case 404:
          throw const UpdateException(
            'Релизы не найдены. Репозиторий должен быть публичным, '
            'а в нём — опубликованный релиз.',
          );
        case 403:
        case 429:
          throw const UpdateException(
            'GitHub временно ограничил запросы. Попробуй через несколько минут.',
          );
        default:
          throw UpdateException(
            'GitHub ответил кодом ${response.statusCode}.',
          );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const UpdateException('Не удалось разобрать ответ GitHub.');
      }

      final tag = (decoded['tag_name'] as String? ?? '').trim();
      final remoteVersion = stripVersionPrefix(tag);
      if (remoteVersion.isEmpty) {
        throw const UpdateException('В релизе нет номера версии.');
      }

      final apk = _findApk(decoded['assets']);
      if (apk == null) {
        throw const UpdateException('В последнем релизе нет APK.');
      }

      final current = await ApkInstaller.appVersion();
      if (compareVersions(remoteVersion, current.version) <= 0) {
        return null;
      }

      return UpdateInfo(
        version: remoteVersion,
        notes: (decoded['body'] as String? ?? '').trim(),
        apkUrl: apk.url,
        sizeBytes: apk.size,
      );
    } on TimeoutException {
      throw const UpdateException(
        'GitHub не ответил вовремя. Проверь интернет и попробуй снова.',
      );
    } on SocketException {
      throw const UpdateException(
        'Нет связи с GitHub. Проверь интернет или VPN.',
      );
    } on HttpException {
      throw const UpdateException('Не удалось связаться с GitHub.');
    } on IOException {
      throw const UpdateException('Ошибка сети при связи с GitHub.');
    } on FormatException {
      throw const UpdateException('GitHub вернул непонятный ответ.');
    } finally {
      client.close(force: true);
    }
  }

  /// Скачивает APK во временную папку приложения и возвращает файл.
  Future<File> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final cache = await getTemporaryDirectory();
    final directory = Directory(
      '${cache.path}${Platform.pathSeparator}updates',
    );
    await directory.create(recursive: true);
    await _removeOldApks(directory);

    final safeVersion = info.version.replaceAll(
      RegExp(r'[^0-9A-Za-z._-]'),
      '-',
    );
    final target = File(
      '${directory.path}${Platform.pathSeparator}offload-$safeVersion.apk',
    );
    final partial = File('${target.path}.part');
    if (await partial.exists()) {
      await partial.delete();
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(info.apkUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'Offload-Android');
      final response = await request.close().timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        throw UpdateException(
          'Не удалось скачать APK: код ${response.statusCode}.',
        );
      }

      final total = response.contentLength > 0
          ? response.contentLength
          : info.sizeBytes;
      sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (total > 0 && received != total) {
        throw const UpdateException(
          'Файл скачался не полностью. Попробуй ещё раз.',
        );
      }
      if (await target.exists()) {
        await target.delete();
      }
      return await partial.rename(target.path);
    } on TimeoutException {
      throw const UpdateException(
        'Скачивание прервалось. Попробуй ещё раз.',
      );
    } on SocketException {
      throw const UpdateException(
        'Связь оборвалась во время скачивания. Попробуй ещё раз.',
      );
    } on IOException {
      throw const UpdateException(
        'Ошибка сети во время скачивания. Попробуй ещё раз.',
      );
    } finally {
      if (sink != null) {
        await sink.close();
      }
      client.close(force: true);
      if (await partial.exists()) {
        await partial.delete();
      }
    }
  }

  Future<void> _removeOldApks(Directory directory) async {
    await for (final entity in directory.list()) {
      if (entity is File &&
          (entity.path.endsWith('.apk') || entity.path.endsWith('.part'))) {
        await entity.delete();
      }
    }
  }

  _ApkAsset? _findApk(Object? assets) {
    if (assets is! List) {
      return null;
    }
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) {
        continue;
      }
      final name = (asset['name'] as String? ?? '').toLowerCase();
      final url = asset['browser_download_url'] as String?;
      if (url != null && name.endsWith('.apk')) {
        return _ApkAsset(
          url: url,
          size: (asset['size'] as num?)?.toInt() ?? 0,
        );
      }
    }
    return null;
  }
}

class _ApkAsset {
  const _ApkAsset({required this.url, required this.size});

  final String url;
  final int size;
}
