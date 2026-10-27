import '../models/note.dart';

/// Хранилище заметок. Реализация решает, где лежат данные — на телефоне
/// (файл) или в памяти (тесты).
abstract class NoteStore {
  Future<List<Note>> load();

  Future<Note> add(String text);

  Future<Note> update(
    int id, {
    String? text,
    bool? completed,
    String? color,
  });

  Future<void> delete(int id);
}

/// Ошибка чтения или записи локального хранилища.
class StorageException implements Exception {
  const StorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
