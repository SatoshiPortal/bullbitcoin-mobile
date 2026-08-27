import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

class Bip39WordList {
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
    bip39.Language language = bip39.Language.english,
  }) {
    try {
      return bip39.Mnemonic.lastWordCandidates(
        words: words,
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
  /// trie is warranted.
  static Set<String> allowedNextLetters({
    required String prefix,
    bip39.Language language = bip39.Language.english,
  }) {
    final letters = <String>{};
    for (final word in language.list) {
      if (word.length > prefix.length && word.startsWith(prefix)) {
        letters.add(word[prefix.length]);
      }
    }
    return letters;
  }
}
