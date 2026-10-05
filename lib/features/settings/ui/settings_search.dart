import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

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

/// Combining marks left behind by the canonical decomposition below.
final _combiningMarks = RegExp(r'[\u0300-\u036f]');

/// Apostrophes a soft keyboard produces, versus the one a user actually types.
final _apostrophes = RegExp('[\u2018\u2019\u02bc\u00b4`]');

final _separators = RegExp(r'[_\-–—]+');

final _whitespace = RegExp(r'\s+');

/// Folds a title, a keyword or a query down to what a comparison should see.
///
/// Decomposing to NFD and dropping the combining marks is what makes the search
/// accent-insensitive: `Sécurité` and `securite` both collapse to `securite`, so
/// a user who does not reach for the accented key still finds the setting. NFD
/// covers every script the app ships, which a hand-written Latin table would
/// not — Vietnamese and Greek carry diacritics just as French does.
///
/// Applied to both sides of every comparison, so the folding stays symmetric.
///
/// Known limit: `ä` folds to `a`, not to the `ae` some German users type. The
/// two cannot both be reached by a single normalization, and dropping the
/// diaeresis is what a phone keyboard makes easy.
String _normalize(String value) => unorm
    .nfd(value.toLowerCase())
    .replaceAll(_combiningMarks, '')
    .replaceAll('ß', 'ss')
    .replaceAll(_apostrophes, "'")
    .replaceAll(_separators, ' ')
    .replaceAll(_whitespace, ' ')
    .trim();
