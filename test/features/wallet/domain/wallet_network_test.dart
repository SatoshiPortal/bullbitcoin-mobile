import 'package:primitives/primitives.dart' show UnsupportedNetworkException;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' as primitives;

void main() {
  group('Network', () {
    // Six values, no signet, Liquid last; the persistence contract is tested in the data-layer suite.
    test('persists six names with regtest third and no signet', () {
      expect(Network.values.map((network) => network.name).toList(), [
        'bitcoinMainnet',
        'bitcoinTestnet',
        'bitcoinRegtest',
        'liquidMainnet',
        'liquidTestnet',
        'liquidRegtest',
      ]);
    });

    test(
      'assigns coin type 0 to Bitcoin mainnet and 1776 to Liquid mainnet',
      () {
        const expected = <Network, int>{
          Network.bitcoinMainnet: 0,
          Network.bitcoinTestnet: 1,
          Network.bitcoinRegtest: 1,
          Network.liquidMainnet: 1776,
          Network.liquidTestnet: 1,
          Network.liquidRegtest: 1,
        };
        for (final network in Network.values) {
          expect(network.coinType, expected[network], reason: network.name);
        }
      },
    );

    test('derives chain and environment flags from the value', () {
      for (final network in Network.values) {
        expect(network.isLiquid, !network.isBitcoin, reason: network.name);
        expect(
          network.isMainnet,
          network.environment == primitives.NetworkEnv.mainnet,
          reason: network.name,
        );
      }
      expect(Network.liquidTestnet.coinType, 1);
      expect(Network.liquidTestnet.isMainnet, isFalse);
      expect(Network.liquidTestnet.isBitcoin, isFalse);
      expect(Network.bitcoinRegtest.isMainnet, isFalse);
      expect(Network.bitcoinRegtest.isBitcoin, isTrue);
    });

    test('fromName parses its own names only', () {
      for (final network in Network.values) {
        expect(Network.fromName(network.name), network);
      }
      // A foreign name is not remapped: signet has no app value, and a
      // primitives/satoshifier name that is absent here raises the
      // no-element StateError of firstWhere, not a typed failure.
      for (final rejected in [
        'signet',
        'bitcoinSignet',
        'liquidSignet',
        'bitcoinMainnet ',
        '',
      ]) {
        expect(
          () => Network.fromName(rejected),
          throwsStateError,
          reason: rejected,
        );
      }
    });

    test('fromEnvironment maps the three supported environments', () {
      for (final (environment, isLiquid, expected) in [
        (primitives.NetworkEnv.mainnet, false, Network.bitcoinMainnet),
        (primitives.NetworkEnv.testnet, false, Network.bitcoinTestnet),
        (primitives.NetworkEnv.regtest, false, Network.bitcoinRegtest),
        (primitives.NetworkEnv.mainnet, true, Network.liquidMainnet),
        (primitives.NetworkEnv.testnet, true, Network.liquidTestnet),
        (primitives.NetworkEnv.regtest, true, Network.liquidRegtest),
      ]) {
        expect(
          Network.fromEnvironment(environment: environment, isLiquid: isLiquid),
          expected,
          reason: '${environment.name}/${isLiquid ? 'liquid' : 'bitcoin'}',
        );
      }
    });

    test('fromEnvironment refuses signet on both chains', () {
      for (final isLiquid in [false, true]) {
        expect(
          () => Network.fromEnvironment(
            environment: primitives.NetworkEnv.signet,
            isLiquid: isLiquid,
          ),
          throwsA(isA<UnsupportedNetworkException>()),
          reason: 'isLiquid=$isLiquid',
        );
      }
    });

    test('requireHistoricalTestnet answers only mainnet and testnet', () {
      expect(Network.bitcoinMainnet.requireHistoricalTestnet(), isFalse);
      expect(Network.liquidMainnet.requireHistoricalTestnet(), isFalse);
      expect(Network.bitcoinTestnet.requireHistoricalTestnet(), isTrue);
      expect(Network.liquidTestnet.requireHistoricalTestnet(), isTrue);
      // Regtest is refused rather than reported as testnet: a historical
      // service has no regtest backend.
      for (final network in [Network.bitcoinRegtest, Network.liquidRegtest]) {
        expect(
          network.requireHistoricalTestnet,
          throwsA(isA<UnsupportedNetworkException>()),
          reason: network.name,
        );
      }
    });
  });

  group('NetworkX', () {
    test('shared maps every value onto the primitives chain-typed enum', () {
      const expected = <Network, primitives.Network>{
        Network.bitcoinMainnet: primitives.BitcoinNetwork.mainnet,
        Network.bitcoinTestnet: primitives.BitcoinNetwork.testnet,
        Network.bitcoinRegtest: primitives.BitcoinNetwork.regtest,
        Network.liquidMainnet: primitives.LiquidNetwork.mainnet,
        Network.liquidTestnet: primitives.LiquidNetwork.testnet,
        Network.liquidRegtest: primitives.LiquidNetwork.regtest,
      };
      for (final network in Network.values) {
        expect(network.shared, expected[network], reason: network.name);
        // Identity round trips through the environment and coin type.
        expect(network.shared.env, network.environment, reason: network.name);
        expect(network.shared.coinType, network.coinType, reason: network.name);
        expect(
          network.shared.isMainnet,
          network.isMainnet,
          reason: network.name,
        );
      }
    });

    test('the chain-typed getters refuse the other chain', () {
      for (final network in [
        Network.bitcoinMainnet,
        Network.bitcoinTestnet,
        Network.bitcoinRegtest,
      ]) {
        expect(network.bitcoin.env, network.environment, reason: network.name);
        expect(
          () => network.liquid,
          throwsA(isA<ArgumentError>()),
          reason: network.name,
        );
      }
      for (final network in [
        Network.liquidMainnet,
        Network.liquidTestnet,
        Network.liquidRegtest,
      ]) {
        expect(network.liquid.env, network.environment, reason: network.name);
        expect(
          () => network.bitcoin,
          throwsA(isA<ArgumentError>()),
          reason: network.name,
        );
      }
    });
  });
}
