import 'package:silent/src/data/sp_backend_config_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpBackendConfigModel', () {
    test('toJson emits the network name and the urls', () {
      const config = SpBackendConfigModel(
        network: BitcoinNetwork.regtest,
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      );

      expect(config.toJson(), {
        'network': 'regtest',
        'blindbitUrl': 'http://blindbit.example',
        'electrumUrl': 'tcp://electrum.example:50001',
        'fetchConcurrencyFactor': 12,
        'matchConcurrencyFactor': 1,
        'minScanAmountSat': 1000,
        'defaultEndpointsVersion': 1,
      });
    });

    test('fromJson(toJson) round-trips every network', () {
      for (final network in BitcoinNetwork.values) {
        final original = SpBackendConfigModel(
          network: network,
          blindbitUrl: 'http://blindbit.example',
          electrumUrl: 'tcp://electrum.example:50001',
        );

        final restored = SpBackendConfigModel.fromJson(original.toJson());

        expect(restored.network, network);
        expect(restored.blindbitUrl, 'http://blindbit.example');
        expect(restored.electrumUrl, 'tcp://electrum.example:50001');
      }
    });

    test('reads the legacy "bitcoin" network name as mainnet', () {
      // Installs made before the switch to BitcoinNetwork wrote 'bitcoin' for
      // mainnet. Dropping that would leave an existing wallet unloadable.
      final restored = SpBackendConfigModel.fromJson({
        'network': 'bitcoin',
        'blindbitUrl': 'http://blindbit.example',
        'electrumUrl': 'tcp://electrum.example:50001',
        'fetchConcurrencyFactor': 12,
        'matchConcurrencyFactor': 1,
      });

      expect(restored.network, BitcoinNetwork.mainnet);
      expect(restored.minScanAmountSat, 600);
    });

    test(
      'moves exact legacy mainnet defaults without changing custom URLs',
      () {
        final restored = SpBackendConfigModel.fromJson({
          'network': 'mainnet',
          'blindbitUrl': 'https://blindbit.pythcoiner.dev',
          'electrumUrl': 'ssl://electrum.custom.example:50002',
        });
        expect(restored.blindbitUrl, 'https://blindbit.bullbitcoin.com');
        expect(restored.electrumUrl, 'ssl://electrum.custom.example:50002');
      },
    );

    test('preserves explicit legacy URL choices in a versioned record', () {
      const original = SpBackendConfigModel(
        network: BitcoinNetwork.mainnet,
        blindbitUrl: 'https://blindbit.pythcoiner.dev',
        electrumUrl: 'ssl://electrum.pythcoiner.dev:50002',
        minScanAmountSat: 500,
      );
      final restored = SpBackendConfigModel.fromJson(original.toJson());
      expect(restored.blindbitUrl, original.blindbitUrl);
      expect(restored.electrumUrl, original.electrumUrl);
      expect(restored.minScanAmountSat, 500);
    });

    test('an unknown network name still throws', () {
      expect(
        () => SpBackendConfigModel.fromJson({
          'network': 'dogecoin',
          'blindbitUrl': 'http://blindbit.example',
          'electrumUrl': 'tcp://electrum.example:50001',
          'fetchConcurrencyFactor': 12,
          'matchConcurrencyFactor': 1,
        }),
        throwsArgumentError,
      );
    });
  });
}
