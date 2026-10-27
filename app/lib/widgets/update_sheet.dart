import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/apk_installer.dart';
import '../services/update_service.dart';
import '../theme/offload_theme.dart';

/// Открывает нижнюю панель проверки обновлений.
Future<void> showUpdateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => const UpdateSheet(),
  );
}

class UpdateSheet extends StatefulWidget {
  const UpdateSheet({super.key});

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  final UpdateService _service = UpdateService();

  String _currentVersion = '';
  UpdateInfo? _info;
  File? _file;
  String? _error;
  bool _checking = true;
  bool _downloading = false;
  bool _needPermission = false;
  int _received = 0;
  int _total = 0;
  DateTime _lastProgress = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _reset() {
    _checking = true;
    _error = null;
    _info = null;
    _file = null;
    _needPermission = false;
    _received = 0;
    _total = 0;
  }

  Future<void> _start() async {
    setState(_reset);
    await _load();
  }

  Future<void> _load() async {
    try {
      final app = await ApkInstaller.appVersion();
      if (!mounted) {
        return;
      }
      setState(() => _currentVersion = app.version);
      final info = await _service.check();
      if (!mounted) {
        return;
      }
      setState(() {
        _checking = false;
        _info = info;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checking = false;
        _error = _describe(error);
      });
    }
  }

  Future<void> _download() async {
    final info = _info;
    if (info == null || _downloading) {
      return;
    }
    setState(() {
      _downloading = true;
      _error = null;
      _received = 0;
      _total = info.sizeBytes;
    });
    try {
      final file = await _service.download(
        info,
        onProgress: (received, total) {
          if (!mounted) {
            return;
          }
          final now = DateTime.now();
          final finished = total > 0 && received >= total;
          if (!finished &&
              now.difference(_lastProgress) <
                  const Duration(milliseconds: 120)) {
            return;
          }
          _lastProgress = now;
          setState(() {
            _received = received;
            if (total > 0) {
              _total = total;
            }
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _downloading = false;
        _file = file;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _downloading = false;
        _error = _describe(error);
      });
    }
  }

  Future<void> _install() async {
    final file = _file;
    if (file == null) {
      return;
    }
    try {
      final allowed = await ApkInstaller.canInstall();
      if (!mounted) {
        return;
      }
      if (!allowed) {
        setState(() => _needPermission = true);
        return;
      }
      setState(() => _needPermission = false);
      await ApkInstaller.install(file.path);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message ?? 'Не удалось открыть установщик.';
      });
    }
  }

  Future<void> _openPermissionSettings() async {
    try {
      await ApkInstaller.openInstallSettings();
    } on PlatformException {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Не удалось открыть настройки разрешений.';
      });
    }
  }

  String _describe(Object error) {
    if (error is UpdateException) {
      return error.message;
    }
    if (error is MissingPluginException) {
      return 'Обновления работают только в Android-сборке.';
    }
    return 'Не удалось проверить обновления. Попробуй ещё раз.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.system_update_rounded,
                  size: 19,
                  color: palette.accent,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Обновления',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: palette.muted),
                  tooltip: 'Закрыть',
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _currentVersion.isEmpty
                  ? 'Проверка выполняется только по кнопке'
                  : 'Установлена версия $_currentVersion',
              style: TextStyle(fontSize: 11, color: palette.muted),
            ),
            const SizedBox(height: 18),
            ..._buildBody(palette),
            const SizedBox(height: 18),
            Text(
              'Приложение не проверяет обновления само и не отправляет '
              'заметки в сеть. Интернет нужен только сейчас — для загрузки APK.',
              style: TextStyle(
                fontSize: 9.5,
                height: 1.45,
                color: palette.muted.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(OffloadPalette palette) {
    if (_checking) {
      return [
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.accent,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Проверяем GitHub…',
              style: TextStyle(fontSize: 12.5, color: palette.text),
            ),
          ],
        ),
      ];
    }

    final error = _error;
    if (error != null) {
      return [
        _HintCard(
          palette: palette,
          icon: Icons.error_outline_rounded,
          color: palette.warning,
          title: 'Не получилось',
          text: error,
        ),
        const SizedBox(height: 14),
        _SheetButton(
          palette: palette,
          label: 'Попробовать снова',
          onTap: _start,
        ),
      ];
    }

    final info = _info;
    if (info == null) {
      return [
        _HintCard(
          palette: palette,
          icon: Icons.check_circle_outline_rounded,
          color: palette.accent,
          title: 'У вас последняя версия',
          text: 'GitHub не нашёл релиза новее установленного.',
        ),
        const SizedBox(height: 14),
        _SheetButton(
          palette: palette,
          label: 'Проверить ещё раз',
          onTap: _start,
          primary: false,
        ),
      ];
    }

    final size = info.sizeBytes > 0 ? _formatBytes(info.sizeBytes) : null;
    final progress = _total > 0
        ? (_received / _total).clamp(0.0, 1.0).toDouble()
        : null;

    return [
      _HintCard(
        palette: palette,
        icon: Icons.new_releases_outlined,
        color: palette.accent,
        title: 'Доступна версия ${info.version}',
        text: size == null
            ? 'Можно скачать и установить поверх текущей.'
            : 'Размер файла: $size. Установка поверх сохранит заметки.',
      ),
      if (info.notes.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          'Что нового',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          info.notes,
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: palette.text.withValues(alpha: 0.85),
          ),
        ),
      ],
      const SizedBox(height: 16),
      if (_file == null) ...[
        if (_downloading) ...[
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: palette.accent,
                    backgroundColor: palette.border,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                progress == null
                    ? _formatBytes(_received)
                    : '${(progress * 100).round()}%',
                style: TextStyle(fontSize: 11, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Скачиваем APK… Не закрывай приложение.',
            style: TextStyle(fontSize: 10.5, color: palette.muted),
          ),
        ] else
          _SheetButton(
            palette: palette,
            label: 'Скачать ${info.version}',
            onTap: _download,
          ),
      ] else ...[
        Row(
          children: [
            Icon(Icons.download_done_rounded, size: 16, color: palette.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Файл скачан, можно устанавливать',
                style: TextStyle(fontSize: 11.5, color: palette.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_needPermission) ...[
          _HintCard(
            palette: palette,
            icon: Icons.shield_outlined,
            color: palette.warning,
            title: 'Нужно разрешение',
            text: 'Android запрещает ставить APK без подтверждения. '
                'Разреши Offload установку приложений в настройках.',
          ),
          const SizedBox(height: 10),
          _SheetButton(
            palette: palette,
            label: 'Открыть настройки',
            onTap: _openPermissionSettings,
            primary: false,
          ),
          const SizedBox(height: 8),
        ],
        _SheetButton(
          palette: palette,
          label: _needPermission ? 'Я разрешил — установить' : 'Установить',
          onTap: _install,
        ),
      ],
    ];
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 МБ';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} МБ';
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.palette,
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final OffloadPalette palette;
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.palette,
    required this.label,
    required this.onTap,
    this.primary = true,
  });

  final OffloadPalette palette;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? palette.accent : palette.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: primary ? palette.navInk : palette.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
