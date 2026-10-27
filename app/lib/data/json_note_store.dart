import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/note.dart';
import 'note_store.dart';

/// Хранилище заметок в JSON-файле на телефоне.
///
/// Почему JSON, а не SQLite: личных заметок тысячи, а не миллионы; нет нативных
/// зависимостей, данные легко скопировать, а запись атомарная (временный файл +
/// переименование).
class JsonNoteStore implements NoteStore {
  JsonNoteStore({
    required Future<String?> Function() read,
    required Future<void> Function(String payload) write,
  })  : _read = read,
        _write = write;

  /// Хранилище в приватной папке приложения на устройстве.
  static Future<JsonNoteStore> forFile(Directory directory) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}notes.json');
    final temp = File('${file.path}.tmp');
    return JsonNoteStore(
      read: () async => file.existsSync() ? file.readAsString() : null,
      write: (payload) async {
        await temp.writeAsString(payload, flush: true);
        await temp.rename(file.path);
      },
    );
  }

  /// Хранилище по умолчанию: приватная папка приложения на телефоне.
  static Future<JsonNoteStore> open() async {
    final documents = await getApplicationDocumentsDirectory();
    return forFile(
      Directory('${documents.path}${Platform.pathSeparator}offload'),
    );
  }

  static const int formatVersion = 1;

  final Future<String?> Function() _read;
  final Future<void> Function(String payload) _write;

  final List<Note> _notes = [];
  bool _loaded = false;
  int _nextId = 1;
  Future<void> _writeQueue = Future<void>.value();

  @override
  Future<List<Note>> load() async {
    await _ensureLoaded();
    return List<Note>.unmodifiable(_notes);
  }

  @override
  Future<Note> add(String text) {
    return _serialized(() async {
      await _ensureLoaded();
      final note = Note(
        id: _nextId,
        text: _cleanText(text),
        createdAt: DateTime.now(),
      );
      _nextId++;
      _notes.insert(0, note);
      await _persist();
      return note;
    });
  }

  @override
  Future<Note> update(
    int id, {
    String? text,
    bool? completed,
  }) {
    return _serialized(() async {
      await _ensureLoaded();
      final index = _notes.indexWhere((note) => note.id == id);
      if (index < 0) {
        throw const StorageException('Заметка не найдена');
      }
      final updated = _notes[index].copyWith(
        text: text == null ? null : _cleanText(text),
        completed: completed,
      );
      _notes[index] = updated;
      await _persist();
      return updated;
    });
  }

  @override
  Future<void> delete(int id) {
    return _serialized(() async {
      await _ensureLoaded();
      final before = _notes.length;
      _notes.removeWhere((note) => note.id == id);
      if (_notes.length == before) {
        throw const StorageException('Заметка не найдена');
      }
      await _persist();
    });
  }

  /// Операции записи идут строго одна за другой, чтобы два быстрых нажатия не
  /// перезаписали данные наполовину.
  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writeQueue.then((_) => action());
    _writeQueue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    try {
      final raw = await _read();
      if (raw == null || raw.trim().isEmpty) {
        _loaded = true;
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Ожидался объект');
      }

      final items = decoded['notes'];
      if (items is List) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            _notes.add(Note.fromJson(item));
          }
        }
      }

      final storedNextId = decoded['next_id'];
      final maxId = _notes.fold<int>(0, (max, note) {
        return note.id > max ? note.id : max;
      });
      _nextId =
          storedNextId is int && storedNextId > maxId ? storedNextId : maxId + 1;
      _loaded = true;
    } on FormatException {
      throw const StorageException(
        'Файл заметок повреждён. Данные не перезаписаны, чтобы их можно было '
        'восстановить вручную.',
      );
    } on FileSystemException {
      throw const StorageException('Не удалось прочитать файл заметок');
    }
  }

  Future<void> _persist() async {
    final payload = jsonEncode(<String, Object?>{
      'version': formatVersion,
      'next_id': _nextId,
      'notes': [for (final note in _notes) note.toJson()],
    });
    try {
      await _write(payload);
    } on FileSystemException {
      throw const StorageException('Не удалось сохранить заметки');
    }
  }

  String _cleanText(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      throw const StorageException('Текст заметки не может быть пустым');
    }
    return cleaned;
  }
}
