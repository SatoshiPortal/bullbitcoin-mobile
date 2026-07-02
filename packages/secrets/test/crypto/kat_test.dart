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

/// The SAME logical path but with a HARDENED final index (`586053381'`) — the
/// form `generateRecoverbullPath` actually emits. Distinct from the non-hardened
/// vector above (hardened vs. non-hardened derive different keys), so freezing it
/// proves the generator's output path derives deterministically, not just the
/// legacy non-hardened one. Generated once from the zoo seed and FROZEN.
const recoverbullKeyForHardenedPath =
    '8f2c4b36f3a0b36058481ea6e2d740ae9b27d46986e24d92cc288bcacbab58d0';

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
  return Bip32Derivation.xprvFromSeed(seed, BitcoinNetwork.mainnet);
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

  group('BIP39/BIP32 independent published vectors (cross-check, not frozen)', () {
    // These come from the official BIP39 (TREZOR) and BIP32 spec test vectors,
    // NOT from our own output — they catch a SYSTEMATICALLY wrong derivation
    // that a self-frozen vector cannot.
    const bip39AbandonAbout = [
      'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
      'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
    ];

    test('BIP39: "abandon…about" + "TREZOR" → the official 64-byte seed', () {
      final seed = bip39.Mnemonic.fromWords(
        words: bip39AbandonAbout,
        passphrase: 'TREZOR',
      ).seed;
      final hexStr =
          seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
        hexStr,
        'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e5349553'
        '1f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04',
      );
    });

    test('BIP32: seed 000102…0f → master fingerprint 3442193e + master xprv',
        () {
      final seed = Uint8List.fromList(
        List.generate(16, (i) => i), // 000102030405060708090a0b0c0d0e0f
      );
      expect(Bip32Derivation.fingerprintHex(seed), '3442193e');
      expect(
        Bip32Derivation.xprvFromSeed(seed, BitcoinNetwork.mainnet),
        'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKm'
        'PGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi',
      );
    });
  });

  group('BIP85 official spec vectors (authoritative cross-check, not frozen)', () {
    // From the official BIP85 specification test vectors
    // (github.com/bitcoin/bips/blob/master/bip-0085.mediawiki). Unlike the
    // self-frozen vectors below, these catch a SYSTEMATICALLY-wrong BIP85
    // derivation that re-deriving our own output could never detect.
    const bip85MasterXprv =
        'xprv9s21ZrQH143K2LBWUUQRFXhucrQqBpKdRRxNVq2zBqsx8HVqFk2uYo8kmbaLL'
        'HRdqtQpUm98uKfu3vca1LqdGhUtyoFnCNkfmXRyPXLjbKb';

    test('BIP39 app (m/83696968\'/39\'/0\'/12\'/0\') → the spec mnemonic', () {
      // childMnemonicPath confirms the path layout: 39'/0'/12'/0'.
      expect(
        Bip85Crypto.childMnemonicPath(length: MnemonicLength.words12, index: 0),
        "39'/0'/12'/0'",
      );
      final child = Bip85Crypto.deriveChildMnemonic(
        xprvBase58: bip85MasterXprv,
        length: MnemonicLength.words12,
        index: 0,
      );
      expect(
        child.words.join(' '),
        'girl mad pet galaxy egg matter matrix prison refuse sense '
        'ordinary nose',
      );
    });

    test('HEX app (m/83696968\'/128169\'/64\'/0\') → the spec 64-byte hex', () {
      final hexOut = Bip85Crypto.deriveHex(
        xprvBase58: bip85MasterXprv,
        numBytes: 64,
        index: 0,
      );
      expect(
        hexOut,
        '492db4698cf3b73a5a24998aa3e9d7fa96275d85724a91e71aa2d645442f8785'
        '55d078fd1f1f67e368976f04137b1f7a0d19232136ca50c44614af72b5582a5c',
      );
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

    test('HARDENED final index (generator form) derives the frozen key', () {
      // generateRecoverbullPath emits `1608'/0'/{index}'` — a hardened final
      // index. Prove that path derives a stable, distinct key (parity proven,
      // not assumed).
      final key = Bip85Crypto.deriveBackupKeyHex(
        _zooXprv(),
        "1608'/0'/586053381'",
      );
      expect(key, recoverbullKeyForHardenedPath);
      expect(key, isNot(recoverbullKeyForPath)); // hardened ≠ non-hardened
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

  group('templated BIP85 paths validate (Bip85HardenedPath guard)', () {
    // The path producers wrap their string templates in Bip85HardenedPath, so a
    // dropped quote becomes a thrown error instead of a wrong-key derivation.
    // Assert the real templates pass validation (don't throw) and are shaped as
    // expected — coverage the KAT key vectors don't otherwise give.
    test('arkPath is the expected fully-hardened path', () {
      expect(Bip85Crypto.arkPath(), "128169'/32'/11811'");
    });

    test('childMnemonicPath validates for both lengths', () {
      expect(
          Bip85Crypto.childMnemonicPath(
              length: MnemonicLength.words12, index: 0),
          "39'/0'/12'/0'");
      expect(
          Bip85Crypto.childMnemonicPath(
              length: MnemonicLength.words24, index: 5),
          "39'/0'/24'/5'");
    });

    test('generateRecoverbullPath is a valid hardened recoverbull path', () {
      expect(Bip85Crypto.generateRecoverbullPath(),
          matches(RegExp(r"^1608'/0'/\d+'$")));
    });
  });
}
