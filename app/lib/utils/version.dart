/// Работа с версиями вида `1.2.3`, `v1.2.3`, `1.2.3+4`, `1.2.3-beta`.
library;

/// Убирает префикс `v` из тега релиза: `v1.2.3` → `1.2.3`.
String stripVersionPrefix(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final first = trimmed[0];
  if (first == 'v' || first == 'V') {
    return trimmed.substring(1);
  }
  return trimmed;
}

/// Сравнивает две версии. Возвращает 1, если [a] новее [b], -1 — если старее,
/// 0 — если они равны. Суффиксы `-beta` и `+build` при сравнении игнорируются.
int compareVersions(String a, String b) {
  final left = _numericParts(a);
  final right = _numericParts(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) {
      return l.compareTo(r);
    }
  }
  return 0;
}

List<int> _numericParts(String value) {
  var clean = stripVersionPrefix(value);
  final plus = clean.indexOf('+');
  if (plus >= 0) {
    clean = clean.substring(0, plus);
  }
  final dash = clean.indexOf('-');
  if (dash >= 0) {
    clean = clean.substring(0, dash);
  }
  return [
    for (final part in clean.split('.'))
      _leadingNumber(part),
  ];
}

int _leadingNumber(String value) {
  final match = RegExp(r'^\d+').firstMatch(value.trim());
  if (match == null) {
    return 0;
  }
  return int.tryParse(match.group(0)!) ?? 0;
}
