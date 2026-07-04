import 'dart:convert';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// AD-6 independent-oracle vectors: these constants are known-answer values
// produced by the Rust `bullnym` pay-simulator (a DIFFERENT implementation),
// not by signing-then-verifying with bitcoin_base itself. A wrong digest
// construction, a wrong endianness, or a non-deterministic signature would
// fail these — the test cannot pass on a self-consistent-but-wrong derivation.
const _kFixturePrivkeyHex =
    '0101010101010101010101010101010101010101010101010101010101010101';
const _kFixturePubkeyHex =
    '031b84c5567b126440995d3ed5aaba0565d71e1834604819ff9c17f5e9d5dd078f';
const _kFixtureNym = 'alice';
const _kFixtureOutpoint =
    '0000000000000000000000000000000000000000000000000000000000000001:0';
const _kFixtureDigestHex =
    '94df95b4f27f7f2f3cccc31cced7f005f79a1072d13eabb317a83e8eaa1e8a1d';
const _kFixtureSigDerHex =
    '304402205a3152fde9bb2242426f2afb7a3145a87b8fe3d72b25feb11c1427528ffd7dea02202da726a088e0225cb6b84faaa1b53e7f0866fb54581b517b523c95f6477e1663';

const _kMessageTag = 'bullpay-lnurlp-v1';

String _bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('Rust <-> Dart byte-equality with pay-simulator fixture', () {
    test('digest = sha256(tag || nym || outpoint) matches Rust', () {
      final digest = sha256.convert(<int>[
        ...utf8.encode(_kMessageTag),
        ...utf8.encode(_kFixtureNym),
        ...utf8.encode(_kFixtureOutpoint),
      ]).bytes;
      expect(_bytesToHex(digest), _kFixtureDigestHex);
    });

    test('compressed pubkey from privkey matches Rust', () {
      final priv = ECPrivate.fromHex(_kFixturePrivkeyHex);
      expect(priv.getPublic().toHex(), _kFixturePubkeyHex);
    });

    test('ECDSA-DER signature matches Rust (RFC6979 deterministic)', () {
      final digest = sha256.convert(<int>[
        ...utf8.encode(_kMessageTag),
        ...utf8.encode(_kFixtureNym),
        ...utf8.encode(_kFixtureOutpoint),
      ]).bytes;

      final priv = ECPrivate.fromHex(_kFixturePrivkeyHex);
      final sigHex = priv.signECDSA(digest, sighash: null);

      expect(sigHex, _kFixtureSigDerHex);
    });
  });
}
