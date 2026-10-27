import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offload/data/json_note_store.dart';
import 'package:offload/data/note_store.dart';
import 'package:offload/models/note.dart';
import 'package:offload/utils/hashtags.dart';

void main() {
  test('Note parses the stored payload', () {
    final note = Note.fromJson({
      'id': 7,
      'text': 'Проверить MVP #3d #школа',
      'created_at': '2026-10-27T09:30:00.000Z',
      'completed': true,
      'color': '#4ADE80',
    });

    expect(note.id, 7);
    expect(note.text, 'Проверить MVP #3d #школа');
    expect(note.createdAt.isUtc, isTrue);
    expect(note.completed, isTrue);
    expect(note.color, '#4ADE80');
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
    expect(note.color, isEmpty);
    expect(note.tags, isEmpty);
    expect(note.graphLabel, 'Без тегов');
  });

  test('Note survives a JSON round trip', () {
    final original = Note(
      id: 3,
      text: 'Купить кофе #быт',
      createdAt: DateTime.utc(2026, 10, 27, 12, 30),
      completed: true,
      color: '#38BDF8',
    );

    final restored = Note.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.text, original.text);
    expect(restored.createdAt, original.createdAt);
    expect(restored.completed, isTrue);
    expect(restored.color, '#38BDF8');
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

    test('updates text, state and color', () async {
      final note = await store.add('черновик');

      final edited = await store.update(note.id, text: '  финал  ');
      expect(edited.text, 'финал');

      final completed = await store.update(note.id, completed: true);
      expect(completed.completed, isTrue);
      expect(completed.text, 'финал');

      final colored = await store.update(note.id, color: '#F43F5E');
      expect(colored.color, '#F43F5E');
      expect(colored.completed, isTrue);
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
}
