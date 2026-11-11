import 'dart:convert';
import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart' as convert;
import 'package:crypto/crypto.dart';
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

  /// The BIP39 seed of [words] with [passphrase]. Throws bip39's own exception on words that are not a mnemonic — before any PBKDF2 is spent.
  ///
  /// bip39 validates; the PBKDF2 runs on `package:crypto`, about 20× faster than bip39's pointycastle one and paid on every operation. Pinned against bip39 by `seed_pbkdf2_test.dart`.
  Uint8List seed(List<String> words, {String passphrase = ''}) {
    _elements(words);
    final mnemonic = bip39.Mnemonic.fromWords(words: words);
    return _pbkdf2HmacSha512(
      password: utf8.encode(nfkd(mnemonic.words.join(' '))),
      salt: utf8.encode(nfkd('mnemonic$passphrase')),
    );
  }

  /// The master fingerprint of a seed — 4 bytes, 8 lowercase hex.
  Fingerprint fingerprint(Uint8List seed) =>
      Fingerprint(convert.hex.encode(Bip32Keys.fromSeed(seed).fingerprint));

  /// Validates words without deriving a seed: wordlist and checksum only, no PBKDF2. Throws bip39's own exception.
  void check(List<String> words) {
    _elements(words);
    bip39.Mnemonic.fromWords(words: words);
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
  static void _elements(List<String> words) {
    if (!words.every(isMnemonicWordShape)) {
      throw bip39.MnemonicWordNotFoundException(
        '<not a single word>',
        'english',
      );
    }
  }
}

/// BIP39's PBKDF2: HMAC-SHA512, 2048 iterations, one 64-byte block.
Uint8List _pbkdf2HmacSha512({
  required List<int> password,
  required List<int> salt,
}) {
  final hmac = Hmac(sha512, password);
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final t = Uint8List.fromList(u);
  for (var i = 1; i < 2048; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < t.length; j++) {
      t[j] ^= u[j];
    }
  }
  return t;
}
