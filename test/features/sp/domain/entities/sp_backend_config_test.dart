import 'package:bb_mobile/features/sp/data/models/sp_backend_config_model.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpBackendConfig', () {
    test('constructs with non-empty urls', () {
      final config = SpBackendConfig(
        network: SpNetwork.regtest,
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      );

      expect(config.blindbitUrl, 'http://blindbit.example');
      expect(config.electrumUrl, 'tcp://electrum.example:50001');
    });

    test('rejects an empty blindbit url', () {
      expect(
        () => SpBackendConfig(
          network: SpNetwork.regtest,
          blindbitUrl: '',
          electrumUrl: 'tcp://electrum.example:50001',
        ),
        throwsArgumentError,
      );
    });

    test('rejects an empty electrum url', () {
      expect(
        () => SpBackendConfig(
          network: SpNetwork.regtest,
          blindbitUrl: 'http://blindbit.example',
          electrumUrl: '   ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('SpBackendConfigModel', () {
    test('toJson emits the network name and the urls', () {
      const config = SpBackendConfigModel(
        network: SpNetwork.regtest,
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      );

      expect(config.toJson(), {
        'network': 'regtest',
        'blindbitUrl': 'http://blindbit.example',
        'electrumUrl': 'tcp://electrum.example:50001',
        'fetchConcurrencyFactor': SpConfig.defaultFetchConcurrencyFactor,
        'matchConcurrencyFactor': SpConfig.defaultMatchConcurrencyFactor,
      });
    });

    test('fromJson(toJson) round-trips every network', () {
      for (final network in SpNetwork.values) {
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
  });
}
