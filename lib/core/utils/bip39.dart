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
}
