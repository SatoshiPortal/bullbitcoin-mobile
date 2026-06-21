import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/bip32_derivation.dart';
import 'package:secrets/src/crypto/bip85_derivation.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';

/// Frozen Known-Answer-Test vectors, harvested verbatim from the existing app
/// tests (SECRETS_TDD_TESTPLAN §1 / §15). These MUST stay byte-identical.
const zooWrongWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];

const recoverbullKeyForPath =
    '151a5a41f5eac5d49e67e0fad0bddd3beebe0f0e4b7739435997506cf12d9fce';

/// No precomputed in-repo vector existed for ARK; generated once from the zoo
/// seed (path m/83696968'/128169'/32'/11811', 32 bytes) and FROZEN here.
const arkSecretForZooSeed =
    'a30097fcca0406e6003b46b0a8ac5e4af856bf0d31f901b2f580df7d3f5395a3';

/// Frozen master fingerprint of the zoo seed (no passphrase).
const zooFingerprint = '3f635a63';

/// Frozen BIP85 child mnemonic (path 39'/0'/12'/0', index 0) of the zoo seed.
const zooChild0Words =
    'salt option burden habit silent tone breeze fade idle dilemma subway mix';

String _zooXprv() {
  final seed = Uint8List.fromList(
    bip39.Mnemonic.fromWords(words: zooWrongWords).seed,
  );
  return Bip32Derivation.xprvFromSeed(seed, Network.bitcoinMainnet);
}

void main() {
  group('BIP32', () {
    test('fingerprint is deterministic for the zoo seed', () {
      final seed = Uint8List.fromList(
        bip39.Mnemonic.fromWords(words: zooWrongWords).seed,
      );
      final fp = Bip32Derivation.fingerprintHex(seed);
      expect(fp, zooFingerprint); // frozen exact value, not just shape
    });

    test('passphrase changes the fingerprint (BIP39)', () {
      final noPass = Bip32Derivation.fingerprintHex(
        Uint8List.fromList(bip39.Mnemonic.fromWords(words: zooWrongWords).seed),
      );
      final withPass = Bip32Derivation.fingerprintHex(
        Uint8List.fromList(bip39.Mnemonic.fromWords(
          words: zooWrongWords,
          passphrase: 'test',
        ).seed),
      );
      expect(noPass, zooFingerprint);
      expect(withPass, isNot(zooFingerprint));
    });
  });

  group('BIP85 recoverbull backup key (KAT)', () {
    test('m/1608\'/0\'/586053381 derives the frozen key', () {
      final key = Bip85Crypto.deriveBackupKeyHex(
        _zooXprv(),
        "m/1608'/0'/586053381",
      );
      expect(key, recoverbullKeyForPath);
    });

    test('1608\'/0\'/586053381 (no m/) derives the same key', () {
      final key = Bip85Crypto.deriveBackupKeyHex(
        _zooXprv(),
        "1608'/0'/586053381",
      );
      expect(key, recoverbullKeyForPath);
    });
  });

  group('BIP85 child mnemonic paths (KAT)', () {
    test('index0/words12 → 39\'/0\'/12\'/0\'', () {
      expect(
        Bip85Crypto.childMnemonicPath(length: MnemonicLength.words12, index: 0),
        "39'/0'/12'/0'",
      );
    });
    test('index1/words24 → 39\'/0\'/24\'/1\'', () {
      expect(
        Bip85Crypto.childMnemonicPath(length: MnemonicLength.words24, index: 1),
        "39'/0'/24'/1'",
      );
    });
    test('deriveChildMnemonic matches the frozen child words (KAT)', () {
      final child = Bip85Crypto.deriveChildMnemonic(
          xprvBase58: _zooXprv(), length: MnemonicLength.words12, index: 0);
      expect(child.words.join(' '), zooChild0Words); // exact, not just count
    });
  });

  group('ARK secret (generate + freeze)', () {
    test('index 11811 len 32 is deterministic and 32 bytes', () {
      final a = Bip85Crypto.deriveArk(_zooXprv());
      final b = Bip85Crypto.deriveArk(_zooXprv());
      expect(a, b);
      expect(a, hasLength(32));
      final hexStr =
          a.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
      expect(hexStr, arkSecretForZooSeed);
    });
  });
}
