import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  group('NetworkEnv', () {
    test('has exactly four environments, mainnet first and regtest last', () {
      expect(NetworkEnv.values.map((env) => env.name).toList(), [
        'mainnet',
        'testnet',
        'signet',
        'regtest',
      ]);
    });
  });

  group('BitcoinNetwork', () {
    // The enum name is the persisted name: the Ark funding journal stores it and reads it back with `BitcoinNetwork.tryFromName`, and the SP backend config keeps it in JSON, so these exact strings are the contract.
    // The order below is not load-bearing anywhere; it is pinned only so that a reordering shows up in review.
    test('persists one name per environment', () {
      expect(BitcoinNetwork.values.map((network) => network.name).toList(), [
        'mainnet',
        'testnet',
        'signet',
        'regtest',
      ]);
    });

    test('carries the matching environment and is mainnet only on mainnet', () {
      const expected = <BitcoinNetwork, NetworkEnv>{
        BitcoinNetwork.mainnet: NetworkEnv.mainnet,
        BitcoinNetwork.testnet: NetworkEnv.testnet,
        BitcoinNetwork.signet: NetworkEnv.signet,
        BitcoinNetwork.regtest: NetworkEnv.regtest,
      };
      for (final network in BitcoinNetwork.values) {
        expect(network.env, expected[network], reason: network.name);
        expect(
          network.isMainnet,
          network.env == NetworkEnv.mainnet,
          reason: network.name,
        );
      }
    });

    test('uses BIP44 coin type 0 on mainnet and 1 on every test family', () {
      expect(BitcoinNetwork.mainnet.coinType, 0);
      expect(BitcoinNetwork.testnet.coinType, 1);
      expect(BitcoinNetwork.signet.coinType, 1);
      expect(BitcoinNetwork.regtest.coinType, 1);
      for (final network in BitcoinNetwork.values) {
        expect(
          network.coinType,
          network.isMainnet ? 0 : 1,
          reason: network.name,
        );
      }
    });

    test('fromName accepts every persisted name and nothing else', () {
      for (final network in BitcoinNetwork.values) {
        expect(BitcoinNetwork.fromName(network.name), network);
      }
      for (final rejected in ['', 'signet ', 'Mainnet', 'bitcoinMainnet']) {
        expect(
          () => BitcoinNetwork.fromName(rejected),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              'unknown BitcoinNetwork',
            ),
          ),
          reason: rejected,
        );
      }
    });

    test('tryFromName returns null instead of throwing', () {
      for (final network in BitcoinNetwork.values) {
        expect(BitcoinNetwork.tryFromName(network.name), network);
      }
      expect(BitcoinNetwork.tryFromName('Mainnet'), isNull);
      expect(BitcoinNetwork.tryFromName(''), isNull);
    });
  });

  group('LiquidNetwork', () {
    test('persists one name per environment and has no signet', () {
      expect(LiquidNetwork.values.map((network) => network.name).toList(), [
        'mainnet',
        'testnet',
        'regtest',
      ]);
      expect(LiquidNetwork.tryFromName('signet'), isNull);
      expect(() => LiquidNetwork.fromName('signet'), throwsArgumentError);
    });

    test('carries the matching environment and is mainnet only on mainnet', () {
      const expected = <LiquidNetwork, NetworkEnv>{
        LiquidNetwork.mainnet: NetworkEnv.mainnet,
        LiquidNetwork.testnet: NetworkEnv.testnet,
        LiquidNetwork.regtest: NetworkEnv.regtest,
      };
      for (final network in LiquidNetwork.values) {
        expect(network.env, expected[network], reason: network.name);
        expect(
          network.isMainnet,
          network.env == NetworkEnv.mainnet,
          reason: network.name,
        );
      }
    });

    test(
      'uses SLIP-44 coin type 1776 on mainnet and 1 on test environments',
      () {
        expect(LiquidNetwork.mainnet.coinType, 1776);
        expect(LiquidNetwork.testnet.coinType, 1);
        expect(LiquidNetwork.regtest.coinType, 1);
        for (final network in LiquidNetwork.values) {
          expect(
            network.coinType,
            network.isMainnet ? 1776 : 1,
            reason: network.name,
          );
        }
      },
    );

    test('fromName accepts every persisted name and nothing else', () {
      for (final network in LiquidNetwork.values) {
        expect(LiquidNetwork.fromName(network.name), network);
      }
      expect(
        () => LiquidNetwork.fromName('liquidSignet'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'unknown LiquidNetwork',
          ),
        ),
      );
    });
  });

  test('the sealed Network base exposes env, isMainnet and coinType', () {
    // A caller holding the sealed type crosses the chain without knowing it.
    const networks = <Network>[
      BitcoinNetwork.signet,
      BitcoinNetwork.regtest,
      LiquidNetwork.mainnet,
      LiquidNetwork.regtest,
    ];
    expect(networks.map((network) => network.env).toList(), [
      NetworkEnv.signet,
      NetworkEnv.regtest,
      NetworkEnv.mainnet,
      NetworkEnv.regtest,
    ]);
    expect(networks.map((network) => network.isMainnet).toList(), [
      false,
      false,
      true,
      false,
    ]);
    expect(networks.map((network) => network.coinType).toList(), [
      1,
      1,
      1776,
      1,
    ]);
  });
}
