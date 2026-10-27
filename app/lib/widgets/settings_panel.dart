import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/note.dart';
import '../theme/offload_theme.dart';
import 'update_sheet.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.notes,
    required this.storageHealthy,
    required this.onSettingsChanged,
    required this.onColorChanged,
    required this.onShowDrop,
    required this.onFullscreen,
  });

  final AppSettings settings;
  final List<Note> notes;
  final bool storageHealthy;
  final ValueChanged<AppSettings> onSettingsChanged;
  final void Function(Note note, String color) onColorChanged;
  final VoidCallback onShowDrop;
  final VoidCallback onFullscreen;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  static const _colors = [
    '',
    '#4ADE80',
    '#38BDF8',
    '#A855F7',
    '#F43F5E',
    '#F59E0B',
    '#EC4899',
  ];

  int? _selectedNoteId;

  @override
  void initState() {
    super.initState();
    _selectedNoteId = widget.notes.isEmpty ? null : widget.notes.first.id;
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notes.isEmpty) {
      _selectedNoteId = null;
      return;
    }
    if (!widget.notes.any((note) => note.id == _selectedNoteId)) {
      _selectedNoteId = widget.notes.first.id;
    }
  }

  Note? get _selectedNote {
    if (widget.notes.isEmpty) {
      return null;
    }
    for (final note in widget.notes) {
      if (note.id == _selectedNoteId) {
        return note;
      }
    }
    return widget.notes.first;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final settings = widget.settings;

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
                      (widget.storageHealthy ? palette.accent : palette.warning)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.storageHealthy ? 'Локально' : 'Ошибка данных',
                  style: TextStyle(
                    color: widget.storageHealthy
                        ? palette.accent
                        : palette.warning,
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Режим приложения',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Убрать рамку телефона и занять весь экран',
                      style: TextStyle(
                        fontSize: 10,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AccentButton(
                label: 'Во весь экран',
                onPressed: widget.onFullscreen,
              ),
            ],
          ),
        ),
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SliderHeader(
                title: 'Ширина нод и нитей',
                value: '${settings.nodeScale.toStringAsFixed(1)}x',
                palette: palette,
              ),
              _StyledSlider(
                value: settings.nodeScale,
                min: 0.5,
                max: 2.2,
                divisions: 17,
                onChanged: (value) {
                  widget.onSettingsChanged(
                    settings.copyWith(nodeScale: value),
                  );
                },
                onChangeEnd: (_) => widget.onShowDrop(),
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Цвет одной заметки',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.notes.isEmpty ? null : widget.onShowDrop,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Показать каплю'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _NoteColorDropdown(
                notes: widget.notes,
                selectedId: _selectedNoteId,
                onChanged: (value) {
                  setState(() {
                    _selectedNoteId = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final color in _colors)
                    _ColorSwatch(
                      color: color,
                      selected:
                          (_selectedNote?.color.toUpperCase() ?? '') == color,
                      onTap: widget.notes.isEmpty
                          ? null
                          : () {
                              final note = _selectedNote;
                              if (note != null) {
                                widget.onColorChanged(note, color);
                              }
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SliderHeader(
                title: 'Исчезновение капли графа',
                value: '${settings.dropHideSeconds.toStringAsFixed(1)} сек',
                palette: palette,
              ),
              _StyledSlider(
                value: settings.dropHideSeconds,
                min: 1,
                max: 8,
                divisions: 14,
                onChanged: (value) {
                  widget.onSettingsChanged(
                    settings.copyWith(dropHideSeconds: value),
                  );
                },
                onChangeEnd: (_) => widget.onShowDrop(),
              ),
              _SliderHints(
                left: 'Быстро (1 сек)',
                center: '2.5 сек',
                right: 'Долго (8 сек)',
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
                  widget.onSettingsChanged(
                    settings.copyWith(navSpeedMs: value),
                  );
                },
              ),
            ],
          ),
        ),
        _SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.storage_rounded, size: 17, color: palette.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.notes.length} '
                      '${_plural(widget.notes.length, 'заметка', 'заметки', 'заметок')} на телефоне',
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
        const SizedBox(height: 10),
        _SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: padding,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(999),
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
        trackHeight: 5,
        activeTrackColor: palette.accent,
        inactiveTrackColor: palette.border,
        thumbColor: palette.accent,
        overlayColor: palette.accentSoft,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 17),
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

class _AccentButton extends StatelessWidget {
  const _AccentButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: palette.accent,
        backgroundColor: palette.accentSoft,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: palette.accent.withValues(alpha: 0.34),
          ),
        ),
        textStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

class _NoteColorDropdown extends StatelessWidget {
  const _NoteColorDropdown({
    required this.notes,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Note> notes;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (notes.isEmpty) {
      return Text(
        'Сначала добавьте заметку — здесь появится выбор.',
        style: TextStyle(fontSize: 11, color: palette.muted),
      );
    }

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedId,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(20),
          dropdownColor: palette.card,
          icon: Icon(Icons.expand_more_rounded, size: 17, color: palette.muted),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: palette.text,
          ),
          items: [
            for (final note in notes)
              DropdownMenuItem<int>(
                value: note.id,
                child: Text(
                  '${note.icon} ${note.graphLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parsed = color.isEmpty ? const Color(0xFFE4E4E7) : _parse(color);
    return Tooltip(
      message: color.isEmpty ? 'По умолчанию' : color,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            color: parsed,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? palette.accent
                  : palette.text.withValues(alpha: 0.16),
              width: selected ? 2.2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: parsed.withValues(alpha: 0.55),
                      blurRadius: 9,
                    ),
                  ]
                : null,
          ),
          child: color.isEmpty
              ? const Icon(Icons.restart_alt_rounded, size: 13)
              : null,
        ),
      ),
    );
  }

  Color _parse(String value) {
    final clean = value.replaceFirst('#', '');
    final parsed = int.tryParse(clean, radix: 16);
    if (parsed == null) {
      return Colors.grey;
    }
    return Color(0xFF000000 | parsed);
  }
}
