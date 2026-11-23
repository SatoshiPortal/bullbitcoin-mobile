import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:satoshifier/satoshifier.dart';
import 'package:primitives/primitives.dart' show XpubType;

void main() {
  group('Network', () {
    // The names are never stored: the only cross-type use is in memory, where the app parses a satoshifier name with its own `Network.fromName` (`WatchOnlyWalletEntity.keyNetwork`), so six of these seven strings must match the app enum and `bitcoinSignet` has no app value.
    // Liquid has no signet, hence seven values.
    test('names one value per chain and environment', () {
      expect(Network.values.map((network) => network.name).toList(), [
        'bitcoinMainnet',
        'bitcoinTestnet',
        'bitcoinSignet',
        'bitcoinRegtest',
        'liquidMainnet',
        'liquidTestnet',
        'liquidRegtest',
      ]);
    });

    test('chain flags follow the value', () {
      for (final network in Network.values) {
        expect(network.isBitcoin, !network.isLiquid, reason: network.name);
      }
      expect(
        [
          for (final network in Network.values)
            if (network.isBitcoin) network.name,
        ],
        ['bitcoinMainnet', 'bitcoinTestnet', 'bitcoinSignet', 'bitcoinRegtest'],
      );
      expect(
        [
          for (final network in Network.values)
            if (network.isLiquid) network.name,
        ],
        ['liquidMainnet', 'liquidTestnet', 'liquidRegtest'],
      );
    });

    test('only mainnet carries real value', () {
      for (final network in Network.values) {
        expect(
          network.isMainnet,
          network.name.endsWith('Mainnet'),
          reason: network.name,
        );
        expect(network.isTestnet, !network.isMainnet, reason: network.name);
      }
      // Signet and regtest are test networks here; unlike the app wallet enum,
      // this package keeps signet as a first-class value.
      expect(Network.bitcoinSignet.isMainnet, isFalse);
      expect(Network.bitcoinSignet.isTestnet, isTrue);
    });
  });

  group('toBdk', () {
    test('maps the four Bitcoin values one to one', () {
      expect(Network.bitcoinMainnet.toBdk, bdk.Network.bitcoin);
      expect(Network.bitcoinTestnet.toBdk, bdk.Network.testnet);
      expect(Network.bitcoinSignet.toBdk, bdk.Network.signet);
      expect(Network.bitcoinRegtest.toBdk, bdk.Network.regtest);
    });

    test('refuses Liquid values with a plain String throw', () {
      for (final network in [
        Network.liquidMainnet,
        Network.liquidTestnet,
        Network.liquidRegtest,
      ]) {
        // Frozen on purpose: this path throws a String, not an Exception.
        expect(
          () => network.toBdk,
          throwsA(isA<String>()),
          reason: network.name,
        );
      }
    });
  });

  group('fromBdkNetwork', () {
    test('collapses testnet3 and testnet4 onto one Bitcoin testnet value', () {
      expect(
        Network.fromBdkNetwork(bdk.Network.bitcoin),
        Network.bitcoinMainnet,
      );
      expect(
        Network.fromBdkNetwork(bdk.Network.testnet),
        Network.bitcoinTestnet,
      );
      expect(
        Network.fromBdkNetwork(bdk.Network.testnet4),
        Network.bitcoinTestnet,
        reason: 'testnet4 has no dedicated value',
      );
      expect(Network.fromBdkNetwork(bdk.Network.signet), Network.bitcoinSignet);
      expect(
        Network.fromBdkNetwork(bdk.Network.regtest),
        Network.bitcoinRegtest,
      );
    });

    test('never yields a Liquid value', () {
      for (final network in bdk.Network.values) {
        expect(
          Network.fromBdkNetwork(network).isBitcoin,
          isTrue,
          reason: '$network',
        );
      }
    });
  });

  group('fromLwkNetwork', () {
    test('maps the three Liquid values one to one', () {
      expect(
        Network.fromLwkNetwork(lwk.LiquidNetwork.mainnet),
        Network.liquidMainnet,
      );
      expect(
        Network.fromLwkNetwork(lwk.LiquidNetwork.testnet),
        Network.liquidTestnet,
      );
      expect(
        Network.fromLwkNetwork(lwk.LiquidNetwork.regtest),
        Network.liquidRegtest,
      );
    });

    test('never yields a Bitcoin value', () {
      for (final network in lwk.LiquidNetwork.values) {
        expect(
          Network.fromLwkNetwork(network).isLiquid,
          isTrue,
          reason: '$network',
        );
      }
    });
  });

  group('fromXpubType', () {
    test('reads the SLIP-132 family as mainnet or the test family', () {
      const expected = <XpubType, Network>{
        XpubType.xpub: Network.bitcoinMainnet,
        XpubType.ypub: Network.bitcoinMainnet,
        XpubType.zpub: Network.bitcoinMainnet,
        XpubType.tpub: Network.bitcoinTestnet,
        XpubType.upub: Network.bitcoinTestnet,
        XpubType.vpub: Network.bitcoinTestnet,
      };
      for (final type in XpubType.values) {
        expect(Network.fromXpubType(type), expected[type], reason: type.name);
      }
    });

    test('cannot name signet, regtest or Liquid', () {
      // A test-family xpub encodes testnet versus signet versus regtest no more
      // than a shared test address does: only two answers exist here.
      for (final type in XpubType.values) {
        expect(
          Network.fromXpubType(type),
          anyOf(Network.bitcoinMainnet, Network.bitcoinTestnet),
        );
      }
    });
  });

  group('CoinType', () {
    test('uses 0, 1 and 1776 and refuses anything else', () {
      expect(CoinType.bitcoin.value, 0);
      expect(CoinType.testnet.value, 1);
      expect(CoinType.liquid.value, 1776);
      expect(CoinType.fromInt(0), CoinType.bitcoin);
      expect(CoinType.fromInt(1), CoinType.testnet);
      expect(CoinType.fromInt(1776), CoinType.liquid);
      for (final rejected in [2, 60, 1777]) {
        // Frozen on purpose: an unknown coin type throws a String.
        expect(() => CoinType.fromInt(rejected), throwsA(isA<String>()));
      }
    });

    test('toNetwork collapses every test family onto one value', () {
      expect(CoinType.bitcoin.toNetwork(), Network.bitcoinMainnet);
      expect(CoinType.testnet.toNetwork(), Network.bitcoinTestnet);
      // 1776 identifies Liquid, not its environment: the Liquid test and
      // regtest paths land on liquidMainnet here, and a caller that needs the
      // environment must supply it separately.
      expect(CoinType.liquid.toNetwork(), Network.liquidMainnet);
    });
  });

  group('Descriptor.coinType', () {
    Descriptor descriptorFor(Network network) => Descriptor(
      operand: ScriptOperand.wpkh,
      fingerprint: 'aabbccdd',
      pubkey: 'public-key',
      network: network,
      derivation: Derivation.bip84,
      account: 0,
    );

    test('assigns coin type 0 only to Bitcoin mainnet', () {
      for (final network in Network.values) {
        expect(
          descriptorFor(network).coinType,
          network.isBitcoin && network.isMainnet
              ? CoinType.bitcoin
              : network.isBitcoin
              ? CoinType.testnet
              : CoinType.liquid,
          reason: network.name,
        );
      }
    });

    test('folds signet and regtest into coin type 1', () {
      expect(descriptorFor(Network.bitcoinSignet).coinType, CoinType.testnet);
      expect(descriptorFor(Network.bitcoinRegtest).coinType, CoinType.testnet);
    });

    test('gives Liquid testnet and regtest coin type 1776', () {
      // Differs from the app wallet enum, where both are coin type 1.
      expect(descriptorFor(Network.liquidTestnet).coinType, CoinType.liquid);
      expect(descriptorFor(Network.liquidRegtest).coinType, CoinType.liquid);
      expect(descriptorFor(Network.liquidMainnet).coinType, CoinType.liquid);
    });
  });
}
