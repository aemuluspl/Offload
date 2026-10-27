import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offload/data/json_note_store.dart';
import 'package:offload/data/note_store.dart';
import 'package:offload/models/app_settings.dart';
import 'package:offload/models/note.dart';
import 'package:offload/screens/home_screen.dart';
import 'package:offload/theme/offload_theme.dart';
import 'package:offload/utils/hashtags.dart';
import 'package:offload/widgets/graph_orb.dart';

void main() {
  test('Note parses the stored payload', () {
    final note = Note.fromJson({
      'id': 7,
      'text': 'Проверить MVP #3d #школа',
      'created_at': '2026-10-27T09:30:00.000Z',
      'completed': true,
      // Старое поле color из версии 1.0.1 должно игнорироваться.
      'color': '#4ADE80',
    });

    expect(note.id, 7);
    expect(note.text, 'Проверить MVP #3d #школа');
    expect(note.createdAt.isUtc, isTrue);
    expect(note.completed, isTrue);
    expect(note.tags, ['#3d', '#школа']);
    expect(note.graphLabel, 'Проверить MVP (#3d #школа)');
  });

  test('Hashtags are normalized and deduplicated', () {
    expect(
      extractHashtags('Идея #3D и ещё раз #3d, плюс #Школа'),
      ['#3d', '#школа'],
    );
    expect(stripHashtags('  Заметка: купить PETG #3d  '), 'Заметка: купить PETG');
    expect(stripNotePrefix('Эмоция: спокойствие'), 'спокойствие');
  });

  test('Missing optional fields fall back safely', () {
    final note = Note.fromJson({
      'id': 1,
      'text': 'Без тегов',
      'created_at': '2026-10-27T09:30:00.000Z',
    });

    expect(note.completed, isFalse);
    expect(note.tags, isEmpty);
    expect(note.graphLabel, 'Без тегов');
  });

  test('Note survives a JSON round trip', () {
    final original = Note(
      id: 3,
      text: 'Купить кофе #быт',
      createdAt: DateTime.utc(2026, 10, 27, 12, 30),
      completed: true,
    );

    final restored = Note.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.text, original.text);
    expect(restored.createdAt, original.createdAt);
    expect(restored.completed, isTrue);
  });

  group('JsonNoteStore', () {
    late Directory tempDir;
    late JsonNoteStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('offload_test_');
      store = await JsonNoteStore.forFile(tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists notes between instances', () async {
      final created = await store.add('  Первая мысль  ');
      expect(created.text, 'Первая мысль');
      expect(created.id, 1);

      final reopened = await JsonNoteStore.forFile(tempDir);
      final notes = await reopened.load();

      expect(notes, hasLength(1));
      expect(notes.first.text, 'Первая мысль');
      expect(notes.first.id, 1);
    });

    test('adds newest notes first and keeps ids unique', () async {
      await store.add('старая');
      await store.add('новая');

      final notes = await store.load();

      expect([for (final n in notes) n.text], ['новая', 'старая']);
      expect(notes.first.id, greaterThan(notes.last.id));
    });

    test('updates text and state', () async {
      final note = await store.add('черновик');

      final edited = await store.update(note.id, text: '  финал  ');
      expect(edited.text, 'финал');

      final completed = await store.update(note.id, completed: true);
      expect(completed.completed, isTrue);
      expect(completed.text, 'финал');
    });

    test('deletes notes and survives reopen', () async {
      final note = await store.add('удалить меня');
      await store.delete(note.id);

      expect(await store.load(), isEmpty);
      final reopened = await JsonNoteStore.forFile(tempDir);
      expect(await reopened.load(), isEmpty);
    });

    test('rejects empty text', () async {
      final note = await store.add('черновик');
      await expectLater(
        store.add('   '),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        store.update(note.id, text: '   '),
        throwsA(isA<StorageException>()),
      );
      final notes = await store.load();
      expect(notes.single.text, 'черновик');
    });

    test('reports missing note on update and delete', () async {
      await expectLater(
        store.update(42, completed: true),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        store.delete(42),
        throwsA(isA<StorageException>()),
      );
    });

    test('continues ids after reopen', () async {
      await store.add('первая');
      await store.add('вторая');

      final reopened = await JsonNoteStore.forFile(tempDir);
      final third = await reopened.add('третья');

      expect(third.id, 3);
    });

    test('keeps data in readable json file', () async {
      await store.add('Проверить файл');

      final file = File('${tempDir.path}${Platform.pathSeparator}notes.json');
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), contains('Проверить файл'));
    });
  });

  testWidgets('composer morphs between mic and send', (tester) async {
    final store = _MemoryNoteStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOffloadTheme(dark: true),
        home: HomeScreen(
          settings: const AppSettings(),
          onSettingsChanged: (_) {},
          noteStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    final micBefore = tester.getCenter(find.byIcon(Icons.mic_none_rounded));

    final composer = find.byKey(const Key('composer-input'));
    await tester.enterText(composer, 'Новая мысль #идея');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final micAfter = tester.getCenter(find.byIcon(Icons.mic_none_rounded));
    expect(micAfter.dx, lessThan(micBefore.dx));
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(store.notes, hasLength(1));
    expect(store.notes.single.text, 'Новая мысль #идея');
    expect(tester.takeException(), isNull);
  });

  testWidgets('2D graph renders and starts the history timeline', (tester) async {
    final notes = [
      Note(
        id: 3,
        text: 'Третья #идея',
        createdAt: DateTime.utc(2026, 10, 28, 12),
      ),
      Note(
        id: 2,
        text: 'Вторая #идея',
        createdAt: DateTime.utc(2026, 10, 28, 11),
      ),
      Note(
        id: 1,
        text: 'Первая #идея',
        createdAt: DateTime.utc(2026, 10, 28, 10),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOffloadTheme(dark: true),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 260,
              child: GraphOrb(
                notes: notes,
                nodeScale: 1,
                activeTag: null,
                onTagSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}

class _MemoryNoteStore implements NoteStore {
  final List<Note> notes = [];
  int _nextId = 1;

  @override
  Future<List<Note>> load() async => List<Note>.unmodifiable(notes);

  @override
  Future<Note> add(String text) async {
    final note = Note(
      id: _nextId++,
      text: text.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    notes.insert(0, note);
    return note;
  }

  @override
  Future<Note> update(
    int id, {
    String? text,
    bool? completed,
  }) async {
    final index = notes.indexWhere((note) => note.id == id);
    if (index < 0) {
      throw const StorageException('Заметка не найдена');
    }
    final updated = notes[index].copyWith(text: text, completed: completed);
    notes[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(int id) async {
    notes.removeWhere((note) => note.id == id);
  }
}
