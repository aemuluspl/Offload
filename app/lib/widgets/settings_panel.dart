import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/note.dart';
import '../theme/offload_theme.dart';
import 'update_sheet.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.notes,
    required this.storageHealthy,
    required this.onSettingsChanged,
    required this.onShowDrop,
  });

  final AppSettings settings;
  final List<Note> notes;
  final bool storageHealthy;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onShowDrop;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                'НАСТРОЙКИ',
                style: TextStyle(
                  color: palette.text.withValues(alpha: 0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color:
                      (storageHealthy ? palette.accent : palette.warning)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(palette.radius),
                ),
                child: Text(
                  storageHealthy ? 'Локально' : 'Ошибка данных',
                  style: TextStyle(
                    color: storageHealthy ? palette.accent : palette.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Размер узлов графа',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${settings.nodeScale.toStringAsFixed(1)}x',
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: onShowDrop,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.muted,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Капля'),
                  ),
                ],
              ),
              _StyledSlider(
                value: settings.nodeScale,
                min: 0.5,
                max: 2.2,
                divisions: 17,
                onChanged: (value) {
                  onSettingsChanged(settings.copyWith(nodeScale: value));
                },
                onChangeEnd: (_) => onShowDrop(),
              ),
              _SliderHints(
                left: 'Тонкие (0.5x)',
                center: 'Стандарт (1.0x)',
                right: 'Крупные (2.2x)',
                palette: palette,
              ),
            ],
          ),
        ),
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SliderHeader(
                title: 'Скорость анимации панели',
                value: '${settings.navSpeedMs.round()} мс',
                palette: palette,
              ),
              _StyledSlider(
                value: settings.navSpeedMs,
                min: 60,
                max: 500,
                divisions: 44,
                onChanged: (value) {
                  onSettingsChanged(settings.copyWith(navSpeedMs: value));
                },
              ),
            ],
          ),
        ),
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 17,
                    color: palette.accent,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Кастомизация интерфейса',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Меняется сразу, без перезапуска',
                style: TextStyle(fontSize: 9.5, color: palette.muted),
              ),
              const SizedBox(height: 8),
              _SliderHeader(
                title: 'Радиус скруглений',
                value: '${settings.cornerRadius.round()} px',
                palette: palette,
              ),
              _StyledSlider(
                value: settings.cornerRadius,
                min: 4,
                max: 40,
                divisions: 18,
                onChanged: (value) {
                  onSettingsChanged(settings.copyWith(cornerRadius: value));
                },
              ),
              _SliderHints(
                left: 'Почти квадрат',
                center: 'Мягкие',
                right: 'Овальные',
                palette: palette,
              ),
              Divider(height: 18, color: palette.border),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Глубокий чёрный',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          settings.isDark
                              ? 'Фон #000000, как рамка телефона'
                              : 'Доступно в тёмной теме',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.isDark && settings.deepBlack,
                    onChanged: settings.isDark
                        ? (value) {
                            onSettingsChanged(
                              settings.copyWith(deepBlack: value),
                            );
                          }
                        : null,
                    activeThumbColor: palette.navInk,
                    activeTrackColor: palette.accent,
                    inactiveThumbColor: palette.muted,
                    inactiveTrackColor: palette.border,
                  ),
                ],
              ),
            ],
          ),
        ),
        _SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.storage_rounded, size: 17, color: palette.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${notes.length} '
                      '${_plural(notes.length, 'заметка', 'заметки', 'заметок')} на телефоне',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Работает без интернета и без компьютера',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        _SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showUpdateSheet(context),
            child: Row(
              children: [
                Icon(
                  Icons.system_update_rounded,
                  size: 17,
                  color: palette.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Обновления',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Проверить новую версию через GitHub',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.muted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _plural(int value, String one, String few, String many) {
  final mod10 = value % 10;
  final mod100 = value % 100;
  if (mod10 == 1 && mod100 != 11) {
    return one;
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return few;
  }
  return many;
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: padding,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(palette.radius),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}

class _SliderHeader extends StatelessWidget {
  const _SliderHeader({
    required this.title,
    required this.value,
    required this.palette,
  });

  final String title;
  final String value;
  final OffloadPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: palette.accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StyledSlider extends StatelessWidget {
  const _StyledSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: palette.accent,
        inactiveTrackColor: palette.border,
        thumbColor: palette.accent,
        overlayColor: palette.accentSoft,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        trackShape: const RoundedRectSliderTrackShape(),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value.clamp(min, max).toDouble(),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

class _SliderHints extends StatelessWidget {
  const _SliderHints({
    required this.left,
    required this.center,
    required this.right,
    required this.palette,
  });

  final String left;
  final String center;
  final String right;
  final OffloadPalette palette;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 9.5, color: palette.muted);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: style),
        Text(center, style: style),
        Text(right, style: style),
      ],
    );
  }
}
