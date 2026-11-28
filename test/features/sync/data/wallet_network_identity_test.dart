import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart' show nativeWalletStoragePath;

import '../../../../packages/secrets/test/support/open_inventory.dart';

const vectors = <(String, Network, String, String)>[
  (
    'bitcoinMainnet',
    BitcoinNetwork.mainnet,
    'wpkh([aabbccdd/84h/0h/0h])',
    'wpkh([aabbccdd/84h/0h/0h])',
  ),
  (
    'bitcoinTestnet',
    BitcoinNetwork.testnet,
    'wpkh([aabbccdd/84h/1h/0h])',
    'wpkh([aabbccdd/84h/1h/0h])',
  ),
  (
    'bitcoinRegtest',
    BitcoinNetwork.regtest,
    'wpkh([aabbccdd/84h/1h/0h]):regtest',
    'wpkh([aabbccdd/84h/1h/0h])',
  ),
  (
    'liquidMainnet',
    LiquidNetwork.mainnet,
    'elwpkh([aabbccdd/84h/1776h/0h])',
    'elwpkh([aabbccdd/84h/1776h/0h])',
  ),
  (
    'liquidTestnet',
    LiquidNetwork.testnet,
    'elwpkh([aabbccdd/84h/1h/0h])',
    'elwpkh([aabbccdd/84h/1h/0h])',
  ),
  (
    'liquidRegtest',
    LiquidNetwork.regtest,
    'elwpkh([aabbccdd/84h/1h/0h]):regtest',
    'elwpkh([aabbccdd/84h/1h/0h])',
  ),
];

RegisteredWalletDescriptor descriptor(
  String code,
  String id,
  Network network,
) => RegisteredWalletDescriptor(
  id: id,
  network: code,
  externalDescriptor: network is LiquidNetwork
      ? 'ct(slip77(blinding),elwpkh(public))'
      : 'wpkh(public)',
  internalDescriptor: 'wpkh(change)',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('historical codes, origins, script and concrete identities survive catalog projection', () async {
    final rows = [
      for (final (code, network, id, _) in vectors)
        descriptor(code, id, network),
    ];
    final catalog = catalogForTesting(() async => Ok(rows));
    for (final (code, network, id, origin) in vectors) {
      final result = await catalog.find(WalletKey(id: id, network: network));
      expect(
        result,
        isA<Ok<PublicWalletDescriptor, SyncFailure>>(),
        reason: code,
      );
      final value = (result as Ok<PublicWalletDescriptor, SyncFailure>).value;
      expect(value.key, WalletKey(id: id, network: network));
      expect(value.origin, origin);
      expect(value.scriptType, ScriptType.bip84);
    }
    // The catalog couples the ':regtest' id suffix to the network code in both
    // directions; a row that disagrees is refused rather than projected.
    for (final (code, id, network) in [
      (
        'bitcoinTestnet',
        'wpkh([aabbccdd/84h/1h/0h]):regtest',
        BitcoinNetwork.testnet,
      ),
      ('bitcoinRegtest', 'wpkh([aabbccdd/84h/1h/0h])', BitcoinNetwork.regtest),
    ]) {
      final mismatched = catalogForTesting(
        () async => Ok([descriptor(code, id, network)]),
      );
      expect(
        await mismatched.find(WalletKey(id: id, network: network)),
        isA<Err<PublicWalletDescriptor, SyncFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<SyncInvalidCatalogFailure>(),
        ),
        reason: '$code $id',
      );
    }
    for (final rejected in [
      'unresolved',
      'signet',
      'bitcoinSignet',
      'liquidSignet',
      'BitcoinMainnet',
      'bitcoinMainnet ',
      '',
      '0',
    ]) {
      final invalid = catalogForTesting(
        () async => Ok([
          descriptor(rejected, vectors.first.$3, BitcoinNetwork.mainnet),
        ]),
      );
      final result = await invalid.find(
        WalletKey(id: vectors.first.$3, network: BitcoinNetwork.mainnet),
      );
      expect(
        result,
        isA<Err<PublicWalletDescriptor, SyncFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<SyncInvalidCatalogFailure>(),
        ),
        reason: rejected,
      );
    }
    expect(
      await catalog.find(
        WalletKey(id: vectors[1].$3, network: BitcoinNetwork.signet),
      ),
      isA<Err<PublicWalletDescriptor, SyncFailure>>(),
    );
  });

  test('coin types, chain and environment remain exact', () {
    for (final (network, env, coin, bitcoin)
        in <(Network, NetworkEnv, int, bool)>[
          (BitcoinNetwork.mainnet, NetworkEnv.mainnet, 0, true),
          (BitcoinNetwork.testnet, NetworkEnv.testnet, 1, true),
          (BitcoinNetwork.regtest, NetworkEnv.regtest, 1, true),
          (LiquidNetwork.mainnet, NetworkEnv.mainnet, 1776, false),
          (LiquidNetwork.testnet, NetworkEnv.testnet, 1, false),
          (LiquidNetwork.regtest, NetworkEnv.regtest, 1, false),
        ]) {
      expect(network.env, env);
      expect(network.coinType, coin);
      expect(network.isMainnet, env == NetworkEnv.mainnet);
      expect(network is BitcoinNetwork, bitcoin);
      expect(network is LiquidNetwork, !bitcoin);
    }
    expect(Environment.mainnet.requireHistoricalTestnet(), isFalse);
    expect(Environment.testnet.requireHistoricalTestnet(), isTrue);
    expect(
      Environment.regtest.requireHistoricalTestnet,
      throwsA(isA<UnsupportedEnvironmentException>()),
    );
    expect(LiquidNetwork.tryFromName('signet'), isNull);
  });

  test(
    'real inventory selects mainnet, testnet and regtest separately',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'wallet-networks-',
      );
      final fixture = await openFreshInventory(directory);
      addTearDown(() async {
        await fixture.inventory.close();
        await fixture.admission.close();
        await directory.delete(recursive: true);
      });
      for (final (code, network, id, _) in vectors) {
        final liquid = network is LiquidNetwork;
        valueOf(
          await fixture.inventory.registerWallet(
            watchOnlyWallet(
              id,
              network: code,
              external: liquid
                  ? 'ct(slip77(blinding),elwpkh(public))'
                  : 'wpkh(public)',
              internal: 'wpkh(change)',
            ),
          ),
        );
      }
      for (final (_, network, id, _) in vectors) {
        final selection = valueOf(
          await fixture.inventory.walletsForNetwork(network),
        );
        expect(selection.isComplete, isTrue);
        expect(selection.wallets.map((wallet) => wallet.id), [id]);
        expect(selection.wallets.single.network, network);
      }
      expect(
        await fixture.inventory.walletsForNetwork(BitcoinNetwork.signet),
        isA<Err<WalletSelection, SecretFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<UnsupportedNetworkFailure>(),
        ),
      );
      expect(
        nativeWalletStoragePath(
          '/wallets',
          WalletKey(id: vectors[1].$3, network: BitcoinNetwork.testnet),
        ),
        isNot(
          nativeWalletStoragePath(
            '/wallets',
            WalletKey(id: vectors[2].$3, network: BitcoinNetwork.regtest),
          ),
        ),
      );
    },
  );
}
