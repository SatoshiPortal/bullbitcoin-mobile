import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/crypto/descriptor_derivation.dart';

// H1 regression: the private-key guard on the derived descriptor MUST match an
// actual xprv/tprv key expression, NOT the bare substring `prv`. A bare
// `contains('prv')` false-positives on the base58 xpub/tpub body and the bech32
// descriptor checksum (both alphabets include p/r/v), and since the account
// xpub is deterministic per seed, that fails closed on EVERY derivation forever
// — deterministically bricking ~1 in 1000 wallets. These tests pin the anchored
// behaviour so a regression to `contains('prv')` fails CI.
void main() {
  bool leaks(String d) => DescriptorDerivation.descriptorContainsPrivateKey(d);

  group('descriptorContainsPrivateKey — genuine private descriptors leak', () {
    test('xprv after an origin ]', () {
      expect(
        leaks("wpkh([d34db33f/84'/0'/0']xprv9s21ZrQH143K3.../0/*)#checksum"),
        isTrue,
      );
    });
    test('tprv after an origin ]', () {
      expect(
        leaks("wpkh([d34db33f/84'/1'/0']tprv8ZgxMBicQKsPd.../0/*)#checksum"),
        isTrue,
      );
    });
    test('xprv right after the function (', () {
      expect(leaks('wpkh(xprv9s21ZrQH143K3.../0/*)'), isTrue);
    });
    test('tprv after a , separator (multisig)', () {
      expect(
        leaks('sortedmulti(2,tprv8ZgxMBicQKsPd...,tpubDCZv...)'),
        isTrue,
      );
    });
  });

  group('descriptorContainsPrivateKey — public descriptors do NOT false-fire',
      () {
    test('a public descriptor is clean', () {
      expect(
        leaks("wpkh([d34db33f/84'/0'/0']xpub6CUGRUo.../0/*)#checksum"),
        isFalse,
      );
    });
    test('xpub body incidentally containing the substring "prv"', () {
      // The base58 body can spell p/r/v consecutively; it is NOT at a key
      // boundary, so it must not be treated as a private key.
      expect(leaks("wpkh([fp/84'/0'/0']xpub6CprvUo123456/0/*)#ab12cd34"),
          isFalse);
    });
    test('xpub body incidentally containing the substring "xprv"', () {
      expect(leaks("wpkh([fp/84'/0'/0']xpub6Cxprv0123456/0/*)#ab12cd34"),
          isFalse);
    });
    test('bech32 checksum incidentally containing "prv"', () {
      expect(leaks("wpkh([fp/84'/0'/0']xpub6CUGRUo.../0/*)#prv0abcd"), isFalse);
    });
  });
}
