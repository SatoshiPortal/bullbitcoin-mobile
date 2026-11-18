import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart' as convert;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:meta/meta.dart';
import 'package:unorm_dart/unorm_dart.dart';

/// How a secret gets its fingerprint: words → seed → BIP32 master fingerprint.
///
/// Pure, and the only place this computation lives. `data/` files a secret under the fingerprint this returns and checks it on the way back out; neither step derives anything itself. Reached as `Deriver.fingerprint`.
final class FingerprintDeriver {
  @internal
  const FingerprintDeriver();

  /// The BIP39 seed of [words] in [language] with [passphrase]. Throws bip39's own exception on words that are not a mnemonic.
  ///
  /// bip39 validates and derives; the package keeps no PBKDF2 of its own.
  Uint8List seed(
    List<String> words, {
    String passphrase = '',
    required bip39.Language language,
  }) {
    words = normalizeWords(words);
    _elements(words, language);
    final derived = bip39.Mnemonic.fromWords(
      words: words,
      language: language,
      passphrase: passphrase,
    ).seed;
    final seed = Uint8List.fromList(derived);
    derived.fillRange(0, derived.length, 0);
    return seed;
  }

  /// Canonical BIP39 spelling, without changing element boundaries.
  List<String> normalizeWords(List<String> words) => words.map(nfkd).toList();

  /// Bark's public consistency identity for an already scoped English child.
  /// The path and empty passphrase are part of existing Ark account identity.
  Fingerprint arkFingerprint(List<String> words) {
    final bytes = seed(words, language: bip39.Language.english);
    try {
      final purpose = Bip32Keys.fromSeed(bytes).deriveHardened(350);
      return Fingerprint(convert.hex.encode(purpose.fingerprint));
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  /// The master fingerprint of a seed — 4 bytes, 8 lowercase hex.
  Fingerprint fingerprint(Uint8List seed) =>
      Fingerprint(convert.hex.encode(Bip32Keys.fromSeed(seed).fingerprint));

  /// Validates words without deriving a seed: wordlist and checksum only, no PBKDF2. Throws bip39's own exception.
  void check(List<String> words, {required bip39.Language language}) {
    words = normalizeWords(words);
    _elements(words, language);
    bip39.Mnemonic.fromWords(words: words, language: language);
  }

  /// Refuses a list whose elements are not one word each — see
  /// [isMnemonicWordShape] for why bip39 alone does not.
  ///
  /// Applied in [seed] as well as [check] so that `idOf` and `import` refuse
  /// the same lists. Throws bip39's own [bip39.MnemonicWordNotFoundException]: an
  /// element that is not a single word is, exactly, a word not found in the
  /// wordlist, and that type is what the boundary already classifies as an
  /// invalid mnemonic. The placeholder stands in for the element so that no
  /// candidate word ever enters an exception message, redacted or not.
  static void _elements(List<String> words, bip39.Language language) {
    if (!words.every(isMnemonicWordShape)) {
      throw bip39.MnemonicWordNotFoundException(
        '<not a single word>',
        language.name,
      );
    }
  }
}
