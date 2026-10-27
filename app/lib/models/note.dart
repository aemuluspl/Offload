import '../utils/hashtags.dart';

class Note {
  const Note({
    required this.id,
    required this.text,
    required this.createdAt,
    this.completed = false,
    this.color = '',
  });

  final int id;
  final String text;
  final DateTime createdAt;
  final bool completed;
  final String color;

  factory Note.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final text = json['text'];
    final createdAt = json['created_at'];

    if (id is! int || text is! String || createdAt is! String) {
      throw const FormatException('Некорректные данные заметки.');
    }

    return Note(
      id: id,
      text: text,
      createdAt: DateTime.parse(createdAt),
      completed: json['completed'] == true,
      color: json['color'] is String ? json['color'] as String : '',
    );
  }

  String get createdAtLabel {
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;

    String two(int value) => value.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';

    if (difference == 0) {
      return 'сегодня, $time';
    }
    if (difference == 1) {
      return 'вчера, $time';
    }
    return '${two(local.day)}.${two(local.month)}.${local.year}, $time';
  }

  bool get isEmotion {
    final normalized = text.toLowerCase();
    return normalized.contains('эмоц') || normalized.contains('настро');
  }

  String get icon => isEmotion ? '🎯' : '📝';

  List<String> get tags => extractHashtags(text);

  String get graphLabel {
    final clean = stripNotePrefix(stripHashtags(text));
    final words = clean.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    final shortWords = words.take(2).join(' ');
    if (tags.isEmpty) {
      return shortWords.isEmpty ? 'Мысль' : shortWords;
    }
    return '${shortWords.isEmpty ? 'Мысль' : shortWords} (${tags.join(' ')})';
  }

  Note copyWith({
    String? text,
    bool? completed,
    String? color,
  }) {
    return Note(
      id: id,
      text: text ?? this.text,
      createdAt: createdAt,
      completed: completed ?? this.completed,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'created_at': createdAt.toUtc().toIso8601String(),
      'completed': completed,
      'color': color,
    };
  }
}
