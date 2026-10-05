import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// The BIP352 scan credential, checked against bdk deriving the same paths.
///
/// bdk is the oracle: a second BIP32 implementation, in Rust, that never saw
/// `Bip352Deriver`. The scan key is compared as the raw secret bytes its WIF
/// carries, the spend key as the compressed point its extended public key
/// carries, and the taproot descriptor against bdk's own BIP86 template. The
/// literal strings at the end are bwk-dart's own fixture derivation.
void main() {
  const words =
      'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';
  const passphrase = 'silent';

  Future<Secret> imported(String passphrase) async => ok(
    await Secrets(
      scratchDirectory: () async => Directory.systemTemp.path,
    ).import(words: words.split(' '), passphrase: passphrase),
  );

  /// bdk's root key for [words] under [passphrase], encoded for [network].
  T withRoot<T>(
    String passphrase,
    BitcoinNetwork network,
    T Function(bdk.DescriptorSecretKey root) body,
  ) {
    final mnemonic = bdk.Mnemonic.fromString(mnemonic: words);
    final root = bdk.DescriptorSecretKey(
      networkKind: _kind(network),
      mnemonic: mnemonic,
      password: passphrase.isEmpty ? null : passphrase,
    );
    mnemonic.dispose();
    try {
      return body(root);
    } finally {
      root.dispose();
    }
  }

  ({String scan, String spend, String taproot}) oracle(
    String passphrase,
    BitcoinNetwork network,
  ) => withRoot(passphrase, network, (root) {
    final coin = network.coinType;
    final scanPath = bdk.DerivationPath(path: "m/352'/$coin'/0'/1'/0");
    final spendPath = bdk.DerivationPath(path: "m/352'/$coin'/0'/0'/0");
    final scan = root.derive(path: scanPath);
    final spend = root.derive(path: spendPath);
    final spendPublic = spend.asPublic();
    final taproot = bdk.Descriptor.newBip86(
      secretKey: root,
      keychainKind: bdk.KeychainKind.external_,
      networkKind: _kind(network),
    );
    try {
      final extended = RegExp(
        r'[xt]pub[1-9A-HJ-NP-Za-km-z]+',
      ).firstMatch(spendPublic.toString())!.group(0)!;
      return (
        scan: convert.hex.encode(scan.secretBytes()),
        // The last 33 bytes of a serialized extended public key are its
        // compressed point (BIP32, § Serialization format).
        spend: convert.hex.encode(_base58(extended).sublist(45, 78)),
        taproot: taproot.toString(),
      );
    } finally {
      taproot.dispose();
      spendPublic.dispose();
      spend.dispose();
      scan.dispose();
      spendPath.dispose();
      scanPath.dispose();
    }
  });

  setUp(() => FakeSecureStoragePlatform().install());

  group('every network matches bdk', () {
    for (final network in BitcoinNetwork.values) {
      for (final pass in ['', passphrase]) {
        test('$network${pass.isEmpty ? '' : ' with a passphrase'}', () async {
          final secret = await imported(pass);
          final key = ok(
            await secret.derive.descriptors.silentPayment(network: network),
          );
          final expected = oracle(pass, network);

          final sp = _sp(key.sp);
          expect(sp.wifVersion, network.isMainnet ? 0x80 : 0xef);
          expect(sp.scan, expected.scan);
          expect(sp.spend, expected.spend);
          expect(key.network, network);
          expect(key.fingerprint, secret.id);

          // bdk's template spells the external keychain; bwk's `tr` the
          // multipath `<0;1>`. Same origin, same key.
          final external = expected.taproot.split('#').first;
          expect(key.taproot, external.replaceFirst('/0/*)', '/<0;1>/*)'));
          final coin = network.coinType;
          expect(
            key.taproot,
            matches(
              RegExp(
                '^tr\\(\\[${secret.id.hex}/86\'/$coin\'/0\'\\]'
                '${network.isMainnet ? 'xpub' : 'tpub'}'
                '[1-9A-HJ-NP-Za-km-z]{107}/<0;1>/\\*\\)\$',
              ),
            ),
          );
        });
      }
    }
  });

  test('the shape bwk parses: sp(compressed WIF, compressed point), no '
      'checksum', () async {
    final key = ok(
      await (await imported(
        '',
      )).derive.descriptors.silentPayment(network: BitcoinNetwork.mainnet),
    );
    expect(
      key.sp,
      matches(
        RegExp(r'^sp\([KL][1-9A-HJ-NP-Za-km-z]{51},0[23][0-9a-f]{64}\)$'),
      ),
    );
    expect(key.taproot, isNot(contains('#')));
  });

  test('a passphrase changes every key', () async {
    final plain = ok(
      await (await imported(
        '',
      )).derive.descriptors.silentPayment(network: BitcoinNetwork.mainnet),
    );
    FakeSecureStoragePlatform().install();
    final protected = ok(
      await (await imported(
        passphrase,
      )).derive.descriptors.silentPayment(network: BitcoinNetwork.mainnet),
    );
    expect(_sp(protected.sp).scan, isNot(_sp(plain.sp).scan));
    expect(_sp(protected.sp).spend, isNot(_sp(plain.sp).spend));
    expect(protected.taproot, isNot(plain.taproot));
    expect(protected.fingerprint, isNot(plain.fingerprint));
  });

  test('every test chain shares coin type 1, apart from mainnet', () async {
    final secret = await imported('');
    final keys = {
      for (final network in BitcoinNetwork.values)
        network: ok(
          await secret.derive.descriptors.silentPayment(network: network),
        ),
    };
    final mainnet = keys[BitcoinNetwork.mainnet]!;
    for (final network in BitcoinNetwork.values) {
      if (network.isMainnet) continue;
      final key = keys[network]!;
      expect(_sp(key.sp).scan, isNot(_sp(mainnet.sp).scan));
      expect(_sp(key.sp).spend, isNot(_sp(mainnet.sp).spend));
      expect(key.taproot, contains("/86'/1'/0']tpub"));
      expect(
        key.sp,
        keys[BitcoinNetwork.testnet]!.sp,
        reason: '$network derives under coin type 1',
      );
      expect(key.taproot, keys[BitcoinNetwork.testnet]!.taproot);
    }
    expect(mainnet.taproot, contains("/86'/0'/0']xpub"));
  });

  test('pinned for the published BIP39 test mnemonic', () async {
    // Literal outputs, cross-checked against bdk by the group above: a
    // drift here moves every silent payment wallet to other keys. They are
    // the descriptors bwk-dart's own fixture derives for this mnemonic
    // (`derive` in rust/tests/common/mod.rs, rust-bitcoin directly), the very
    // strings its tests open a watch-only account from.
    final secret = await imported('');
    final mainnet = ok(
      await secret.derive.descriptors.silentPayment(
        network: BitcoinNetwork.mainnet,
      ),
    );
    final testnet = ok(
      await secret.derive.descriptors.silentPayment(
        network: BitcoinNetwork.testnet,
      ),
    );
    expect((mainnet.sp, mainnet.taproot), _mainnet);
    expect((testnet.sp, testnet.taproot), _testnet);
  });

  test('a seed-only secret has no scan key', () async {
    // Refused from the description, before anything is loaded: the wallet
    // the credential watches must be spendable, and signers take words.
    FakeSecureStoragePlatform(
      entries: {
        'seed_aabbccdd': jsonEncode({
          'bytes': List<int>.filled(64, 7),
          'runtimeType': 'bytes',
        }),
      },
    ).install();
    final secret = ok(
      await Secrets(
        scratchDirectory: () async => Directory.systemTemp.path,
      ).fetch(Fingerprint('aabbccdd')),
    );
    final failure = err(
      await secret.derive.descriptors.silentPayment(
        network: BitcoinNetwork.mainnet,
      ),
    );
    expect(failure, isA<MnemonicRequiredFailure>());
  });

  test('its string form names the wallet and nothing else', () async {
    final key = ok(
      await (await imported(
        '',
      )).derive.descriptors.silentPayment(network: BitcoinNetwork.mainnet),
    );
    final printed = key.toString();
    expect(printed, 'SilentPaymentDescriptors(${key.fingerprint}, •••)');
    final sp = _sp(key.sp);
    for (final material in [key.sp, sp.scan, sp.spend, key.taproot]) {
      expect(printed, isNot(contains(material)));
    }
  });
}

bdk.NetworkKind _kind(BitcoinNetwork network) =>
    network.isMainnet ? bdk.NetworkKind.main : bdk.NetworkKind.test;

/// The scan key, its WIF version byte and the spend key of
/// `sp(<WIF>,<point>)`, decoded here rather than by the code under test.
({int wifVersion, String scan, String spend}) _sp(String descriptor) {
  final match = RegExp(
    r'^sp\(([1-9A-HJ-NP-Za-km-z]+),(0[23][0-9a-f]{64})\)$',
  ).firstMatch(descriptor)!;
  final wif = _base58(match.group(1)!, length: 34);
  expect(wif.last, 0x01, reason: 'a compressed-key WIF');
  return (
    wifVersion: wif.first,
    scan: convert.hex.encode(wif.sublist(1, 33)),
    spend: match.group(2)!,
  );
}

/// Base58check payload, checksum dropped.
Uint8List _base58(String text, {int length = 78}) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  var value = BigInt.zero;
  for (final char in text.split('')) {
    value = value * BigInt.from(58) + BigInt.from(alphabet.indexOf(char));
  }
  final bytes = <int>[];
  while (value > BigInt.zero) {
    bytes.insert(0, (value % BigInt.from(256)).toInt());
    value = value ~/ BigInt.from(256);
  }
  final payload = Uint8List.fromList(bytes.sublist(0, bytes.length - 4));
  expect(payload, hasLength(length));
  return payload;
}

const _mainnet = (
  'sp(L1GjghsqGebpTGHowGAbwWDbEuS6SSp1nvi3Pw8iFJVxb4jE18eS,'
      '02fa210b3c4a60b80dd1616f48ae53bbdf0db744b3f9083385108f81be0acb58c6)',
  // BIP86's own account-0 vector for this mnemonic.
  "tr([73c5da0a/86'/0'/0']"
      'xpub6BgBgsespWvERF3LHQu6CnqdvfEvtMcQjYrcRzx53QJjSxarj2afYWcLteoGVky7D3UK'
      'DP9QyrLprQ3VCECoY49yfdDEHGCtMMj92pReUsQ/<0;1>/*)',
);
const _testnet = (
  'sp(cPUL3ngcjvd2hYUan2tfdMxe6B9TdR6Giuie7MWsHuykaCMHg1zY,'
      '02833085c9a716d36b467552c00d6aa8bd42e39adbe98b05bc203110177192f702)',
  "tr([73c5da0a/86'/1'/0']"
      'tpubDDfvzhdVV4unsoKt5aE6dcsNsfeWbTgmLZPi8LQDYU2xixrYemMfWJ3BaVneH3u7DBQe'
      'PdTwhpybaKRU95pi6PMUtLPBJLVQRpzEnjfjZzX/<0;1>/*)',
);
