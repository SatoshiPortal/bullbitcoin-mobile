import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:convert/convert.dart' as convert;
import 'package:primitives/primitives.dart';

/// How a secret gets its identity: words → seed → BIP32 master fingerprint.
///
/// Pure, and the only place this computation lives. `data/` files a secret under the fingerprint this returns and checks it on the way back out; neither step derives anything itself. Reached as `Deriver.identity`.
final class IdentityDeriver {
  const IdentityDeriver();

  /// The BIP39 seed of [words] with [passphrase]. Throws bip39's own exception on words that are not a mnemonic — before any PBKDF2 is spent.
  Uint8List seed(List<String> words, {String passphrase = ''}) =>
      Uint8List.fromList(
        Mnemonic.fromWords(words: words, passphrase: passphrase).seed,
      );

  /// The master fingerprint of a seed — 4 bytes, 8 lowercase hex.
  Fingerprint fingerprint(Uint8List seed) =>
      Fingerprint(convert.hex.encode(Bip32Keys.fromSeed(seed).fingerprint));

  /// Validates words without deriving a seed: wordlist and checksum only, no PBKDF2. Throws bip39's own exception.
  void check(List<String> words) => Mnemonic.fromWords(words: words);
}
