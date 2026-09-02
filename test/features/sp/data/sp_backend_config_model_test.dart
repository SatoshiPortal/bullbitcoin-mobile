import 'package:bb_mobile/features/sp/data/sp_backend_config_model.dart';
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
