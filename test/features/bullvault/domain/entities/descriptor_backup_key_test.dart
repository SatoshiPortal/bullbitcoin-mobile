import 'dart:typed_data';

import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bs58check/bs58check.dart' as base58;
import 'package:flutter_test/flutter_test.dart';

/// Frozen lookup-token vectors.
///
/// Both were produced by an independent Python implementation of BIP32 and
/// SHA-256 that shares no code with the app, from public synthetic seeds of
/// thirty-two repeated bytes. They hold no funds.
const _mainnetXpub =
    'xpub6DknhdAsmeDQc7uaCcTBvPM5HJ2sN2gaBmNiJJtpczK3hMQWdKeodaBUSgi9qJ'
    'rMKqPLqPuNFa7egPzCn8oJ7uU1zzhgAeHvzgYpxqchsQS';
const _mainnetCanonical =
    '000285a865ad265830fe93d2674ea0f169385c9c3e83a64843516dd05c700526d7a3'
    'fec6f54ac15bc4e56f60d09e079d0383cc6c51da078f40de3bd9be1f8e69047d';
const _mainnetToken =
    '284f0cc3191d63691c2181610668f6bbec8bc592839d6a509e10e052efd59f41';
const _testnetTpub =
    'tpubDEXiq2SVhhqALktxfVFgj3C9M3T2G7xL11iezYg2LJAf245YkNyqp2K9TrvHABD'
    'Cp2232k34UegU4aKEtUZNigit8EEqoLNe2JKMzMiLwYq';
const _testnetToken =
    '8ee95e4ce4cc02cdb875736b4849753dd51f9f3d82c779500b10adf1fd091034';

String _hex(Uint8List bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('pins the canonical account bytes and the version 1 lookup token', () {
    expect(
      DescriptorBackupKey.lookupDomain,
      'bullbitcoin-descriptor-lookup-v1',
    );
    final mainnet = DescriptorBackupKey.parse(_mainnetXpub);
    expect(_hex(mainnet.canonicalBytes), _mainnetCanonical);
    expect(mainnet.lookupToken, _mainnetToken);
    expect(DescriptorBackupKey.parse(_testnetTpub).lookupToken, _testnetToken);
  });

  test('the same account derives one token however it is written', () {
    final expected = DescriptorBackupKey.parse(_mainnetXpub).lookupToken;
    // SLIP132 display prefixes describe a script type, not another account.
    final slip132 = base58.decode(_mainnetXpub);
    slip132.buffer.asByteData().setUint32(0, 0x04b24746);
    expect(
      DescriptorBackupKey.parse(base58.encode(slip132)).lookupToken,
      expected,
    );
    for (final written in [
      _mainnetXpub,
      '[11223344/48h/0h/0h/2h]$_mainnetXpub',
      '[11223344/48h/0h/0h/2h]$_mainnetXpub/<0;1>/*',
      '$_mainnetXpub/0/*',
    ]) {
      expect(DescriptorBackupParser.inputKey(written).lookupToken, expected);
    }
  });

  test('a different chain code or network is a different account', () {
    final key = DescriptorBackupKey.parse(_mainnetXpub);
    final otherChainCode = base58.decode(_mainnetXpub)..[13] ^= 1;
    final altered = DescriptorBackupKey.parse(base58.encode(otherChainCode));
    // The x coordinate is unchanged: only BIP138 encryption uses it alone.
    expect(_hex(altered.xOnly), _hex(key.xOnly));
    expect(altered.sameAccount(key), isFalse);
    expect(altered.lookupToken, isNot(key.lookupToken));

    final testnetVersion = base58.decode(_mainnetXpub);
    testnetVersion.buffer.asByteData().setUint32(0, 0x043587cf);
    final testnet = DescriptorBackupKey.parse(base58.encode(testnetVersion));
    expect(testnet.sameAccount(key), isFalse);
    expect(testnet.lookupToken, isNot(key.lookupToken));
  });
}
