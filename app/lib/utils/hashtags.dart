final RegExp _hashtagPattern = RegExp(
  r'#[a-zA-Zа-яА-ЯёЁ0-9_]+',
  unicode: true,
);

List<String> extractHashtags(String text) {
  return _hashtagPattern
      .allMatches(text)
      .map((match) => match.group(0)!.toLowerCase())
      .toSet()
      .toList(growable: false);
}

String stripHashtags(String text) {
  return text
      .replaceAll(_hashtagPattern, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String stripNotePrefix(String text) {
  return text.replaceFirst(
    RegExp(r'^(Заметка|Эмоция|Идея)\s*:\s*', caseSensitive: false),
    '',
  );
}
