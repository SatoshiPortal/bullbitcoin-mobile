import 'package:bb_mobile/features/settings/ui/settings_item.dart';

List<SettingsItem> searchSettings(Iterable<SettingsItem> items, String query) {
  final normalizedQuery = _normalize(query);
  if (normalizedQuery.isEmpty) return [];

  final matches = <({SettingsItem item, int score})>[];
  for (final item in items) {
    final score = _score(item, normalizedQuery);
    if (score != null) matches.add((item: item, score: score));
  }

  matches.sort((a, b) {
    final scoreComparison = a.score.compareTo(b.score);
    if (scoreComparison != 0) return scoreComparison;
    return a.item.title.compareTo(b.item.title);
  });
  return matches.map((match) => match.item).toList(growable: false);
}

int? _score(SettingsItem item, String query) {
  final title = _normalize(item.title);
  if (title == query) return 0;
  if (title.startsWith(query)) return 10;
  if (title.contains(query)) return 20;

  final terms = [...item.path, ...item.keywords].map(_normalize).toList();
  if (terms.any((term) => term == query)) return 30;
  if (terms.any((term) => term.startsWith(query))) return 40;
  if (terms.any((term) => term.contains(query))) return 50;

  final queryTokens = query.split(' ');
  final searchableText = '$title ${terms.join(' ')}';
  if (queryTokens.every(searchableText.contains)) return 60;
  return null;
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[_\-–—]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
