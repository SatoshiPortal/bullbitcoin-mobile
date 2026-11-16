import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:unorm_dart/unorm_dart.dart';

class Bip39WordList {
  /// Normalize each field, including Japanese ideographic space at its edges.
  static String normalize(String word) => nfkd(word.trim());

  /// All possible readings, never an inferred choice. Empty fields are ignored
  /// while typing; a checksum is required only for a completed sentence.
  static List<bip39.Language> matchingLanguages(
    List<String> words, {
    bool requireChecksum = false,
  }) {
    final normalized = words.map(normalize).toList();
    final entered = normalized.where((word) => word.isNotEmpty).toList();
    if (entered.isEmpty) return const [];
    return bip39.Language.values.where((language) {
      if (!entered.every(language.isValid)) return false;
      if (!requireChecksum) return true;
      try {
        bip39.Mnemonic.fromWords(words: normalized, language: language);
        return true;
      } on bip39.MnemonicException {
        return false;
      }
    }).toList();
  }

  /// The words that give [words] a valid checksum once appended to it.
  ///
  /// The last word of a sentence carries the whole checksum, so only a small
  /// share of the wordlist can ever close it: 128 words for a 12 word
  /// sentence, down to 8 for a 24 word one.
  ///
  /// Returns null when the question does not apply — [words] must hold every
  /// word of the sentence but the last, and each of them must belong to
  /// [language].
  static List<String>? lastWordCandidates({
    required List<String> words,
    required bip39.Language language,
  }) {
    try {
      return bip39.Mnemonic.lastWordCandidates(
        words: words.map((word) => nfkd(word.trim())).toList(),
        language: language,
      );
    } on bip39.MnemonicException {
      return null;
    }
  }

  /// The letters that can extend [prefix] toward at least one word of
  /// [language].
  ///
  /// This is what lets the in-app keyboard shrink to only the keys that keep a
  /// word possible: an empty prefix yields every letter some word begins with
  /// (so a letter no word starts with is never offered), and a prefix like
  /// `'a'` excludes `'a'` itself because no wordlist word starts with `'aa'`.
  /// A prefix that is already a complete word with no longer word extending it
  /// yields the empty set — the keyboard then offers backspace only.
  ///
  /// Deliberately answered against the **whole** wordlist even when used on the
  /// last field: narrowing to the checksum candidates would let an earlier typo
  /// that happens to be another valid word hide the real last word, turning the
  /// one error the checksum exists to catch into a silently restored wrong
  /// wallet. The candidate narrowing stays a guidance-only concern of the
  /// suggestion chips.
  ///
  /// A linear scan of the 2048-word list per keystroke is negligible, so no
  /// trie is warranted. The set iterates in wordlist order.
  static Set<String> allowedNextLetters({
    required String prefix,
    required bip39.Language language,
  }) {
    prefix = nfkd(prefix.trim());
    final letters = <String>{};
    for (final entry in language.list) {
      final word = nfkd(entry);
      if (word.length > prefix.length && word.startsWith(prefix)) {
        letters.add(word[prefix.length]);
      }
    }
    return letters;
  }

  /// Whether [language] is written in Latin letters, typed on a letter
  /// keyboard rather than picked from a grid of characters.
  static bool isAlphabetic(bip39.Language language) => switch (language) {
    bip39.Language.english ||
    bip39.Language.spanish ||
    bip39.Language.french ||
    bip39.Language.italian ||
    bip39.Language.czech ||
    bip39.Language.portuguese => true,
    _ => false,
  };

  /// The keys that can extend [prefix] toward at least one word of
  /// [language], in NFKD like every comparison here.
  ///
  /// An alphabetic wordlist is typed one letter at a time, accent included:
  /// `é` is the cluster `e` + U+0301, and a bare `e` is offered only when a
  /// word continues with an unaccented `e`. Other scripts keep one code unit
  /// per key ([allowedNextLetters]), so a Japanese voicing mark or a Korean
  /// jamo stays a key of its own.
  static Set<String> allowedNextKeys({
    required String prefix,
    required bip39.Language language,
  }) {
    if (!isAlphabetic(language)) {
      return allowedNextLetters(prefix: prefix, language: language);
    }
    prefix = nfkd(prefix.trim());
    final keys = <String>{};
    for (final entry in language.list) {
      final word = nfkd(entry);
      if (word.length > prefix.length && word.startsWith(prefix)) {
        keys.add(_letterAt(word, prefix.length));
      }
    }
    return keys;
  }

  /// Every accented letter of an alphabetic [language], in NFKD: grouped by
  /// base letter in alphabetical order, the most frequent accent first within
  /// a base (French `é` before `è`). Empty for a wordlist without accents.
  static List<String> accentedLetters(bip39.Language language) =>
      _accented[language] ??= _accentedLetters(language);

  static final _accented = <bip39.Language, List<String>>{};

  static List<String> _accentedLetters(bip39.Language language) {
    if (!isAlphabetic(language)) return const [];
    final counts = <String, int>{};
    for (final entry in language.list) {
      final word = nfkd(entry);
      var index = 0;
      while (index < word.length) {
        final letter = _letterAt(word, index);
        if (letter.length > 1) counts[letter] = (counts[letter] ?? 0) + 1;
        index += letter.length;
      }
    }
    return counts.keys.toList()..sort((a, b) {
      final base = a[0].compareTo(b[0]);
      if (base != 0) return base;
      final frequency = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      return frequency != 0 ? frequency : a.compareTo(b);
    });
  }

  /// The letter starting at [start]: one code unit and the combining marks
  /// that follow it.
  static String _letterAt(String word, int start) {
    var end = start + 1;
    while (end < word.length && _isCombiningMark(word.codeUnitAt(end))) {
      end++;
    }
    return word.substring(start, end);
  }

  static bool _isCombiningMark(int unit) => unit >= 0x0300 && unit <= 0x036F;

  /// [allowedNextLetters] in key display order. The Chinese wordlists are
  /// sorted by character frequency, so keeping their order puts common
  /// characters first; code point order would scatter 2048 keys. Other
  /// alphabets read best sorted.
  static List<String> orderedNextLetters({
    required String prefix,
    required bip39.Language language,
  }) {
    final letters = allowedNextLetters(
      prefix: prefix,
      language: language,
    ).toList();
    return switch (language) {
      bip39.Language.simplifiedChinese ||
      bip39.Language.traditionalChinese => letters,
      _ => letters..sort(),
    };
  }
}
