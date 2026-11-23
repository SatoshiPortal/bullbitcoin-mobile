import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:swaps/src/data/models/boltz_network.dart';
import 'package:swaps/src/data/models/swap_master_key_model.dart';
import 'package:swaps/src/domain/entities/derived_swap_master_key.dart';
import 'package:swaps/src/util.dart' show Network, SwapsException;
import 'package:test/test.dart';

void main() {
  group('Network', () {
    // The enum name is not persisted by this package; the swap master key
    // stores a NetworkEnv name instead (see the JSON group below). This order
    // is frozen because it differs from the app wallet enum: Liquid mainnet and
    // testnet come before Bitcoin regtest.
    test('has six values in this order', () {
      expect(Network.values.map((network) => network.name).toList(), [
        'bitcoinMainnet',
        'bitcoinTestnet',
        'liquidMainnet',
        'liquidTestnet',
        'bitcoinRegtest',
        'liquidRegtest',
      ]);
    });

    test('fromEnvironment maps the three environments for both chains', () {
      for (final (environment, isLiquid, expected) in [
        (NetworkEnv.mainnet, false, Network.bitcoinMainnet),
        (NetworkEnv.mainnet, true, Network.liquidMainnet),
        (NetworkEnv.testnet, false, Network.bitcoinTestnet),
        (NetworkEnv.testnet, true, Network.liquidTestnet),
        (NetworkEnv.regtest, false, Network.bitcoinRegtest),
        (NetworkEnv.regtest, true, Network.liquidRegtest),
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
            environment: NetworkEnv.signet,
            isLiquid: isLiquid,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              'Unsupported swap network',
            ),
          ),
          reason: 'isLiquid=$isLiquid',
        );
      }
    });

    test('environment collapses the six values back onto three', () {
      const expected = <Network, NetworkEnv>{
        Network.bitcoinMainnet: NetworkEnv.mainnet,
        Network.liquidMainnet: NetworkEnv.mainnet,
        Network.bitcoinTestnet: NetworkEnv.testnet,
        Network.liquidTestnet: NetworkEnv.testnet,
        Network.bitcoinRegtest: NetworkEnv.regtest,
        Network.liquidRegtest: NetworkEnv.regtest,
      };
      for (final network in Network.values) {
        expect(network.environment, expected[network], reason: network.name);
      }
    });

    test('regtest is neither mainnet nor testnet here', () {
      // Frozen on purpose: isTestnet means "the testnet environment", not
      // "not mainnet". Regtest answers false to both, unlike the app wallet
      // enum where isMainnet is the only value-level gate.
      for (final network in [Network.bitcoinRegtest, Network.liquidRegtest]) {
        expect(network.isMainnet, isFalse, reason: network.name);
        expect(network.isTestnet, isFalse, reason: network.name);
      }
      for (final network in [Network.bitcoinMainnet, Network.liquidMainnet]) {
        expect(network.isMainnet, isTrue, reason: network.name);
        expect(network.isTestnet, isFalse, reason: network.name);
      }
      for (final network in [Network.bitcoinTestnet, Network.liquidTestnet]) {
        expect(network.isMainnet, isFalse, reason: network.name);
        expect(network.isTestnet, isTrue, reason: network.name);
      }
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
        ['bitcoinMainnet', 'bitcoinTestnet', 'bitcoinRegtest'],
      );
      expect(
        [
          for (final network in Network.values)
            if (network.isLiquid) network.name,
        ],
        ['liquidMainnet', 'liquidTestnet', 'liquidRegtest'],
      );
    });
  });

  group('DerivedSwapMasterKey', () {
    DerivedSwapMasterKey key(NetworkEnv environment) => DerivedSwapMasterKey(
      walletFingerprint: '00000002',
      xprv: 'xprv',
      xpub: 'xpub',
      mnemonic: 'mnemonic',
      fingerprint: '00000001',
      environment: environment,
    );

    test('isTestnet answers only the testnet environment', () {
      // Regtest is neither mainnet nor testnet here, unlike the satoshifier Network getter where isTestnet is the complement of isMainnet.
      const expected = <NetworkEnv, bool>{
        NetworkEnv.mainnet: false,
        NetworkEnv.testnet: true,
        NetworkEnv.regtest: false,
        NetworkEnv.signet: false,
      };
      for (final environment in NetworkEnv.values) {
        expect(
          key(environment).isTestnet,
          expected[environment],
          reason: environment.name,
        );
      }
    });
  });

  group('SwapMasterKeyModel JSON', () {
    SwapMasterKeyModel key(String network) => SwapMasterKeyModel(
      xprv: 'xprv',
      xpub: 'xpub',
      network: network,
      mnemonic: 'mnemonic',
      fingerprint: '00000001',
    );

    test('stores the environment name, not the chain-typed enum name', () {
      for (final environment in [
        NetworkEnv.mainnet,
        NetworkEnv.testnet,
        NetworkEnv.regtest,
      ]) {
        final stored = SwapMasterKeyModel.fromDerived(
          DerivedSwapMasterKey(
            walletFingerprint: '00000002',
            xprv: 'xprv',
            xpub: 'xpub',
            mnemonic: 'mnemonic',
            fingerprint: '00000001',
            environment: environment,
          ),
        );
        expect(stored.network, environment.name);
        expect(stored.toJson()['network'], environment.name);
        expect(
          SwapMasterKeyModel.fromJson(stored.toJson()).network,
          environment.name,
        );
      }
    });

    test('derives a signet key it cannot read back', () {
      // Nothing rejects signet at derivation time: fromDerived persists the environment name verbatim, so a signet key is stored and only fails when a reader asks for its BoltzNetwork.
      // The guard lives in Network.fromEnvironment and BoltzNetwork.fromEnvironment, not here.
      final stored = SwapMasterKeyModel.fromDerived(
        DerivedSwapMasterKey(
          walletFingerprint: '00000002',
          xprv: 'xprv',
          xpub: 'xpub',
          mnemonic: 'mnemonic',
          fingerprint: '00000001',
          environment: NetworkEnv.signet,
        ),
      );
      expect(stored.network, 'signet');
      expect(stored.toJson()['network'], 'signet');
      expect(() => stored.boltzNetwork, throwsFormatException);
      expect(() => stored.toBoltz(), throwsFormatException);
    });

    test('maps the stored tag onto BoltzNetwork', () {
      expect(key('mainnet').boltzNetwork, BoltzNetwork.mainnet);
      expect(key('testnet').boltzNetwork, BoltzNetwork.testnet);
      expect(key('regtest').boltzNetwork, BoltzNetwork.regtest);
    });

    test('refuses a tag that names no environment', () {
      for (final rejected in ['signet', 'bitcoinMainnet', '']) {
        // Frozen on purpose: an unknown tag raises FormatException, and a
        // per-chain tag such as bitcoinMainnet is not an environment name.
        expect(
          () => key(rejected).boltzNetwork,
          throwsFormatException,
          reason: rejected,
        );
      }
    });

    test('refuses a key whose tag disagrees with the engine environment', () {
      expect(
        () => key('testnet').requireEnvironment(NetworkEnv.regtest),
        throwsA(isA<SwapsException>()),
      );
      expect(
        key('testnet').requireEnvironment(NetworkEnv.testnet).network,
        'testnet',
      );
    });
  });
}
