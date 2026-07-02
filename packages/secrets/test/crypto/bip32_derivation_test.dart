import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/bip32_derivation.dart';
import 'package:secrets/src/domain/secrets_error.dart';

// Direct coverage for convertXpub (the 37b628ca2 neuter-guard hardening had no
// test — a transposed slice would have passed everything else). Uses the frozen
// zoo seed so the SLIP-132 re-versioning is a KAT, not just a shape check.
const zooWrongWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];

/// Frozen zpub (bip84 mainnet, account 0) of the zoo seed — the version-byte
/// re-encoding convertXpub performs. Generated once and FROZEN.
const zooBip84Account0Zpub =
    'zpub6rD5AGSXPTDMSnpmczjENMT3NvVF7q5MySww6uxitUsBYgkZLeBywrcwUWhW5YkeY2aS7xc45APPgfA6s6wWfG2gnfABq6TDz9zqeMu2JCY';

Uint8List _zooSeed() => Uint8List.fromList(bip39.Mnemonic.fromWords(
        words: zooWrongWords, language: bip39.Language.english)
    .seed);

void main() {
  group('convertXpub', () {
    test('re-versions a neutered account key to the SLIP-132 zpub (KAT)', () {
      final acct = Bip32Derivation.accountXpub(
        seedBytes: _zooSeed(),
        scriptType: ScriptType.bip84,
        network: BitcoinNetwork.mainnet,
        account: 0,
      );
      final type = ScriptType.bip84.getXpubType(BitcoinNetwork.mainnet);
      expect(Bip32Derivation.convertXpub(acct, type), zooBip84Account0Zpub);
    });

    test('the emitted key starts with the target zpub version bytes', () {
      final acct = Bip32Derivation.accountXpub(
        seedBytes: _zooSeed(),
        scriptType: ScriptType.bip84,
        network: BitcoinNetwork.mainnet,
        account: 0,
      );
      expect(
        Bip32Derivation.convertXpub(
            acct, ScriptType.bip84.getXpubType(BitcoinNetwork.mainnet)),
        startsWith('zpub'),
      );
    });

    test('THROWS on a non-neutered (private) key — never emits a key-leaking xpub',
        () {
      // A private (xprv) key's data starts with 0x00, not 0x02/0x03; re-versioning
      // it under a public prefix would emit a malformed "xpub" leaking a private
      // scalar. convertXpub must reject it as a programmer bug.
      final privateRoot = bip32.Bip32Keys.fromSeed(_zooSeed());
      expect(
        () => Bip32Derivation.convertXpub(
            privateRoot, ScriptType.bip84.getXpubType(BitcoinNetwork.mainnet)),
        throwsA(isA<InvalidXpubError>()),
      );
    });
  });
}
