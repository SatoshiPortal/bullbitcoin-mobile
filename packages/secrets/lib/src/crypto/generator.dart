import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:secrets/src/domain/domain.dart' show MnemonicWordCount;

/// Produces fresh BIP39 words.
///
/// Concrete and bdk-backed, which is a deliberate trade: it means
/// `Secrets.generate()` cannot be exercised without the FFI layer. The
/// rule it protects is worth more than that testability — how a wallet's
/// seed comes into existence is a security decision, and it must not
/// change as a side effect of moving files around. Swapping bdk's
/// generator for `Random.secure()` + `bip39_mnemonic` would drop a
/// dependency and is probably fine, but it changes how every new wallet
/// in the app is born and deserves its own change and its own review.
class Generator {
  static List<String> mnemonic({
    MnemonicWordCount wordCount = MnemonicWordCount.words12,
  }) {
    // Exhaustive over a closed enum: there is no `_` arm and nothing to throw.
    final words = switch (wordCount) {
      MnemonicWordCount.words12 => bdk.WordCount.words12,
      MnemonicWordCount.words15 => bdk.WordCount.words15,
      MnemonicWordCount.words18 => bdk.WordCount.words18,
      MnemonicWordCount.words21 => bdk.WordCount.words21,
      MnemonicWordCount.words24 => bdk.WordCount.words24,
    };
    // Freed as soon as its words are read: a UniFFI handle holding the
    // fresh mnemonic, which would otherwise sit in native memory until
    // the GC ran. See `BitcoinSigner` for the full note.
    final mnemonic = bdk.Mnemonic(wordCount: words);
    try {
      return mnemonic.toString().split(' ');
    } finally {
      mnemonic.dispose();
    }
  }
}
