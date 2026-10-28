import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/note_store.dart';
import '../models/app_settings.dart';
import '../models/note.dart';
import '../theme/offload_theme.dart';
import '../widgets/graph_orb.dart';
import '../widgets/offload_nav_bar.dart';
import '../widgets/settings_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.noteStore,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final NoteStore noteStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _tabNotes = 0;
  static const _tabStats = 1;
  static const _tabGraph = 2;
  static const _tabTrends = 3;
  static const _tabSettings = 4;

  late final NoteStore _store = widget.noteStore;
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  List<Note> _notes = const [];
  bool _loading = true;
  bool _saving = false;
  bool _storageError = false;
  String? _error;
  String? _activeTag;
  int _activeNav = _tabGraph;
  int _graphPulse = 0;
  int _graphSpin = 0;
  bool _graphExpanded = false;
  bool _dropVisible = false;
  Timer? _dropTimer;
  Timer? _toastTimer;
  String _toastText = '';
  bool _toastVisible = false;

  bool get _isSettings => _activeNav == _tabSettings;
  bool get _isWip => _activeNav == _tabStats || _activeNav == _tabTrends;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _inputController.addListener(_onComposerChanged);
    _inputFocus.addListener(_onComposerChanged);
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _inputController.removeListener(_onComposerChanged);
    _inputFocus.removeListener(_onComposerChanged);
    _inputController.dispose();
    _searchController.dispose();
    _inputFocus.dispose();
    _dropTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _onComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadNotes({bool showSpinner = false}) async {
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
      });
    }
    try {
      final notes = await _store.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _notes = notes;
        _loading = false;
        _storageError = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _storageError = true;
        _error = error.toString();
      });
    }
  }

  Future<void> _addNote() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _saving) {
      _inputFocus.requestFocus();
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final note = await _store.add(text);
      if (!mounted) {
        return;
      }
      _inputController.clear();
      setState(() {
        _notes = [note, ..._notes];
        _saving = false;
        _storageError = false;
        _error = null;
        _graphPulse++;
      });
      _inputFocus.requestFocus();
      if (note.tags.isNotEmpty) {
        _showToast('Сохранено • Связь (${note.tags.join(' ')})');
      } else {
        _showToast('Сохранено в память offload');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _storageError = true;
        _error = error.toString();
      });
      _showToast('Не удалось сохранить мысль');
    }
  }

  Future<void> _toggleNote(Note note) async {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index < 0) {
      return;
    }
    final optimistic = note.copyWith(completed: !note.completed);
    _replaceNote(optimistic);
    try {
      final updated = await _store.update(
        note.id,
        completed: optimistic.completed,
      );
      if (!mounted) {
        return;
      }
      _replaceNote(updated);
      setState(() {
        _storageError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _replaceNote(note);
      setState(() {
        _storageError = true;
        _error = error.toString();
      });
      _showToast('Не удалось изменить заметку');
    }
  }

  Future<void> _deleteNote(Note note) async {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index < 0) {
      return;
    }
    setState(() {
      _notes = _notes.where((item) => item.id != note.id).toList();
      _activeTag = _activeTag != null &&
              !_notes.any((item) => item.tags.contains(_activeTag))
          ? null
          : _activeTag;
    });

    try {
      await _store.delete(note.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _storageError = false;
      });
      _showToast('Заметка удалена из памяти');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        final restored = [..._notes];
        restored.insert(math.min(index, restored.length), note);
        _notes = restored;
        _storageError = true;
        _error = error.toString();
      });
      _showToast('Не удалось удалить заметку');
    }
  }

  Future<void> _editNote(Note note) async {
    final palette = context.palette;
    final controller = TextEditingController(text: note.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(palette.radius),
            side: BorderSide(color: palette.border),
          ),
          title: Text(
            'Редактировать заметку',
            style: TextStyle(
              color: palette.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            maxLength: 4000,
            style: TextStyle(
              color: palette.text,
              fontSize: 14,
              height: 1.35,
            ),
            cursorColor: palette.accent,
            decoration: InputDecoration(
              hintText: 'Текст заметки',
              hintStyle: TextStyle(color: palette.muted, fontSize: 13),
              counterText: '',
              filled: true,
              fillColor: palette.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(palette.radius),
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(palette.radius),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(palette.radius),
                borderSide: BorderSide(color: palette.accent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Отмена',
                style: TextStyle(color: palette.muted),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (newText == null) {
      return;
    }
    final trimmed = newText.trim();
    if (trimmed.isEmpty) {
      _showToast('Текст заметки не может быть пустым');
      return;
    }
    if (trimmed == note.text) {
      return;
    }

    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index < 0) {
      return;
    }
    final original = _notes[index];
    _replaceNote(original.copyWith(text: trimmed));
    try {
      final updated = await _store.update(note.id, text: trimmed);
      if (!mounted) {
        return;
      }
      _replaceNote(updated);
      setState(() {
        _storageError = false;
        _graphPulse++;
      });
      _showToast('Заметка обновлена');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _replaceNote(original);
      setState(() {
        _storageError = true;
        _error = error.toString();
      });
      _showToast('Не удалось сохранить изменения');
    }
  }

  void _replaceNote(Note updated) {
    setState(() {
      _notes = [
        for (final note in _notes)
          if (note.id == updated.id) updated else note,
      ];
    });
  }

  void _selectTab(int index) {
    setState(() {
      _activeNav = index;
      _graphExpanded = false;
      if (index == _tabSettings) {
        _dropVisible = false;
        _dropTimer?.cancel();
      }
      if (index == _tabGraph) {
        _activeTag = null;
        _graphPulse++;
        _graphSpin++;
      }
    });
  }

  void _showDropPreview() {
    if (!_isSettings) {
      return;
    }
    _dropTimer?.cancel();
    setState(() {
      _dropVisible = true;
    });
    _dropTimer = Timer(
      const Duration(seconds: 3),
      () {
        if (mounted && _isSettings) {
          setState(() {
            _dropVisible = false;
          });
        }
      },
    );
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() {
      _toastText = message;
      _toastVisible = true;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1850), () {
      if (mounted) {
        setState(() {
          _toastVisible = false;
        });
      }
    });
  }

  Future<void> _refreshStorage() async {
    await _loadNotes(showSpinner: true);
    if (!mounted) {
      return;
    }
    _showToast(
      _storageError
          ? 'Не удалось прочитать хранилище'
          : 'Данные хранятся на телефоне',
    );
  }

  void _handleVoice() {
    _showToast('Голосовой ввод пока не подключён');
  }

  List<Note> get _filteredNotes {
    final query = _searchController.text.trim().toLowerCase();
    return _notes.where((note) {
      final matchesSearch =
          query.isEmpty || note.text.toLowerCase().contains(query);
      final matchesTag = _activeTag == null || note.tags.contains(_activeTag);
      return matchesSearch && matchesTag;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.page,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useFrame = constraints.maxWidth >= 520;
          if (!useFrame) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 412),
                child: SizedBox(
                  width: math.min(constraints.maxWidth, 412),
                  height: constraints.maxHeight,
                  child: _buildPhone(context, palette),
                ),
              ),
            );
          }

          final phoneWidth = math.min(412.0, constraints.maxWidth - 48);
          final phoneHeight = math.min(915.0, constraints.maxHeight - 24);
          return Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A2B30), Color(0xFF191A1E)],
                ),
                borderRadius: BorderRadius.circular(58),
                border: Border.all(
                  color: const Color(0xFF383A40),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.82),
                    blurRadius: 60,
                    offset: const Offset(0, 26),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(47),
                child: SizedBox(
                  width: phoneWidth,
                  height: phoneHeight,
                  child: _buildPhone(context, palette),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhone(BuildContext context, OffloadPalette palette) {
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final graphHeight = _isSettings
                ? 0.0
                : math.min(
                    360.0,
                    math.max(185.0, constraints.maxHeight * 0.37),
                  );
            return Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildHeader(palette),
                    ),
                    if (!_isSettings) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: graphHeight,
                          child: GraphOrb(
                            notes: _notes,
                            nodeScale: widget.settings.nodeScale,
                            activeTag: _activeTag,
                            pulseToken: _graphPulse,
                            onTagSelected: (tag) {
                              setState(() {
                                _activeTag = tag;
                              });
                            },
                            onNotice: _showToast,
                            onExpand: () {
                              setState(() {
                                _graphExpanded = true;
                                _graphPulse++;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildContent(palette),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OffloadNavBar(
                        activeIndex: _activeNav,
                        animationMs: widget.settings.navSpeedMs,
                        graphSpinToken: _graphSpin,
                        onNotes: () => _selectTab(_tabNotes),
                        onStats: () => _selectTab(_tabStats),
                        onGraph: () => _selectTab(_tabGraph),
                        onTrends: () => _selectTab(_tabTrends),
                        onSettings: () => _selectTab(_tabSettings),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 128,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.text.withValues(alpha: 0.74),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
                _buildDropPreview(palette),
                if (_graphExpanded) _buildExpandedGraph(palette),
                _buildToast(palette),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(OffloadPalette palette) {
    return Row(
      children: [
        _CircleIconButton(
          icon: widget.settings.isDark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          tooltip: widget.settings.isDark
              ? 'Включить светлую тему'
              : 'Включить тёмную тему',
          palette: palette,
          onPressed: () {
            final willBeDark = !widget.settings.isDark;
            widget.onSettingsChanged(
              widget.settings.copyWith(isDark: willBeDark),
            );
            _showToast(willBeDark ? 'Тёмная тема' : 'Светлая тема');
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(palette.radius),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: palette.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                    ),
                    cursorColor: palette.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search...',
                      hintStyle: TextStyle(
                        color: palette.muted,
                        fontSize: 14.5,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: palette.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(OffloadPalette palette) {
    if (_isSettings) {
      return SettingsPanel(
        settings: widget.settings,
        notes: _notes,
        storageHealthy: !_storageError,
        onSettingsChanged: widget.onSettingsChanged,
        onShowDrop: _showDropPreview,
      );
    }
    if (_isWip) {
      return _buildWipPlaceholder(
        palette,
        _activeNav == _tabStats ? 'Аналитика' : 'Динамика',
      );
    }
    return _buildNotes(palette);
  }

  Widget _buildNotes(OffloadPalette palette) {
    final filtered = _filteredNotes;
    return Column(
      children: [
        if (_storageError) ...[
          _StorageBanner(
            palette: palette,
            error: _error,
            onRetry: _refreshStorage,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Text(
              'СЕГОДНЯ',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            if (_activeTag != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _activeTag = null;
                  });
                },
                child: Text(
                  'Сбросить фильтр ✕',
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: palette.accent,
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: palette.accent,
                  backgroundColor: palette.card,
                  onRefresh: () => _loadNotes(),
                  child: _buildNotesList(filtered, palette),
                ),
        ),
        const SizedBox(height: 10),
        _buildComposer(palette),
      ],
    );
  }

  Widget _buildNotesList(List<Note> filtered, OffloadPalette palette) {
    if (filtered.isEmpty) {
      final message = _notes.isEmpty
          ? 'Заметок пока нет. Напишите мысль с #хэштегом снизу!'
          : 'Ничего не найдено. Попробуйте другой запрос.';
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(palette.radius),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.muted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final note = filtered[index];
        return _NoteCard(
          key: ValueKey(note.id),
          note: note,
          palette: palette,
          onToggle: () => _toggleNote(note),
          onEdit: () => _editNote(note),
          onDelete: () => _deleteNote(note),
        );
      },
    );
  }

  Widget _buildComposer(OffloadPalette palette) {
    final typed = _inputController.text.trim().isNotEmpty;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(palette.radius),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const Key('composer-input'),
              controller: _inputController,
              focusNode: _inputFocus,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addNote(),
              style: TextStyle(
                color: palette.text,
                fontSize: 13.5,
              ),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Записать мысль...',
                hintStyle: TextStyle(
                  color: palette.muted,
                  fontSize: 13,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(width: 2),
          AnimatedContainer(
            key: const Key('composer-actions'),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: typed ? 88 : 44,
            height: 44,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  left: typed ? 0 : 4,
                  top: 2,
                  width: 40,
                  height: 40,
                  child: _ComposerButton(
                    icon: Icons.mic_none_rounded,
                    tooltip: 'Голосовой ввод',
                    palette: palette,
                    background: palette.accentSoft,
                    foreground: palette.text,
                    onPressed: _handleVoice,
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  left: typed ? 48 : 40,
                  top: 2,
                  width: 40,
                  height: 40,
                  child: IgnorePointer(
                    ignoring: !typed,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutBack,
                      scale: typed ? 1 : 0.3,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: typed ? 1 : 0,
                        child: _ComposerButton(
                          icon: Icons.arrow_upward_rounded,
                          tooltip: 'Сохранить заметку',
                          palette: palette,
                          background: palette.accent,
                          foreground: palette.navInk,
                          onPressed: _saving ? null : _addNote,
                          busy: _saving,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWipPlaceholder(OffloadPalette palette, String section) {
    return Center(
      child: Container(
        width: 285,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(palette.radius),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded, size: 24, color: palette.muted),
            const SizedBox(height: 7),
            Text(
              'Раздел «$section» в разработке',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Скоро здесь появится подробная статистика ваших мыслей и связей',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropPreview(OffloadPalette palette) {
    final visible = _isSettings && _dropVisible;
    return Positioned(
      top: 54,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: TickerMode(
          enabled: visible,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            offset: visible ? Offset.zero : const Offset(0, -0.25),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: visible ? 1 : 0,
              child: Center(
                child: Container(
                  width: 220,
                  height: 145,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(palette.radius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: palette.graphLine.withValues(alpha: 0.08),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: GraphOrb(
                    notes: _notes,
                    nodeScale: widget.settings.nodeScale,
                    activeTag: _activeTag,
                    compact: true,
                    showChrome: false,
                    onTagSelected: (tag) {
                      setState(() {
                        _activeTag = tag;
                      });
                    },
                    onNotice: _showToast,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedGraph(OffloadPalette palette) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _graphExpanded = false;
          });
        },
        child: ColoredBox(
          color: palette.background.withValues(alpha: 0.9),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 84),
              child: GestureDetector(
                onTap: () {},
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(palette.radius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: GraphOrb(
                    notes: _notes,
                    nodeScale: widget.settings.nodeScale,
                    activeTag: _activeTag,
                    pulseToken: _graphPulse,
                    onTagSelected: (tag) {
                      setState(() {
                        _activeTag = tag;
                      });
                    },
                    onNotice: _showToast,
                    onClose: () {
                      setState(() {
                        _graphExpanded = false;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToast(OffloadPalette palette) {
    return Positioned(
      top: 58,
      left: 22,
      right: 22,
      child: IgnorePointer(
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          offset: _toastVisible ? Offset.zero : const Offset(0, -0.18),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 170),
            opacity: _toastVisible ? 1 : 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: palette.card.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(palette.radius),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  _toastText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final OffloadPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.card,
        shape: CircleBorder(side: BorderSide(color: palette.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 46,
            child: Icon(icon, color: palette.text, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ComposerButton extends StatelessWidget {
  const _ComposerButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final OffloadPalette palette;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: busy
                ? SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: foreground,
                    ),
                  )
                : Icon(icon, size: 20, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _StorageBanner extends StatelessWidget {
  const _StorageBanner({
    required this.palette,
    required this.error,
    required this.onRetry,
  });

  final OffloadPalette palette;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: error ?? 'Не удалось прочитать локальные данные',
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 5, 5, 5),
        decoration: BoxDecoration(
          color: palette.warning.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(palette.radius),
          border: Border.all(
            color: palette.warning.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.storage_rounded, size: 15, color: palette.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ошибка локального хранилища',
                style: TextStyle(
                  color: palette.warning,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: palette.warning,
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    super.key,
    required this.note,
    required this.palette,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Note note;
  final OffloadPalette palette;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: palette.text,
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w500,
      decoration: note.completed ? TextDecoration.lineThrough : null,
      decorationColor: palette.muted,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: note.completed ? 0.55 : 1,
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          onLongPress: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: palette.muted.withValues(
                      alpha: note.completed ? 0.28 : 0.55,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    note.text,
                    style: textStyle,
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Редактировать',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: palette.muted,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Удалить',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
