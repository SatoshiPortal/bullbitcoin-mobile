import 'package:bb_mobile/features/sp/data/mappers/sp_backend_config_mapper.dart';
import 'package:bb_mobile/features/sp/data/sp_backend_config_model.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpBackendConfigMapper.toEntity', () {
    test('carries every field over', () {
      final entity = SpBackendConfigMapper.toEntity(
        const SpBackendConfigModel(
          network: BitcoinNetwork.signet,
          blindbitUrl: 'http://blindbit.example',
          electrumUrl: 'tcp://electrum.example:50001',
          fetchConcurrencyFactor: 8,
          matchConcurrencyFactor: 2,
        ),
      );

      expect(entity.network, BitcoinNetwork.signet);
      expect(entity.blindbitUrl, 'http://blindbit.example');
      expect(entity.electrumUrl, 'tcp://electrum.example:50001');
      expect(entity.fetchConcurrencyFactor, 8);
      expect(entity.matchConcurrencyFactor, 2);
    });

    test('a model with an empty url cannot become an entity', () {
      expect(
        () => SpBackendConfigMapper.toEntity(
          const SpBackendConfigModel(
            network: BitcoinNetwork.regtest,
            blindbitUrl: '',
            electrumUrl: 'tcp://electrum.example:50001',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('a model with an out-of-range factor cannot become an entity', () {
      expect(
        () => SpBackendConfigMapper.toEntity(
          const SpBackendConfigModel(
            network: BitcoinNetwork.regtest,
            blindbitUrl: 'http://blindbit.example',
            electrumUrl: 'tcp://electrum.example:50001',
            fetchConcurrencyFactor: 33,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('SpBackendConfigMapper.toModel', () {
    test('carries every field over', () {
      final model = SpBackendConfigMapper.toModel(
        SpBackendConfig(
          network: BitcoinNetwork.mainnet,
          blindbitUrl: 'https://blindbit.example',
          electrumUrl: 'ssl://electrum.example:50002',
          fetchConcurrencyFactor: 4,
          matchConcurrencyFactor: 3,
        ),
      );

      expect(model.network, BitcoinNetwork.mainnet);
      expect(model.blindbitUrl, 'https://blindbit.example');
      expect(model.electrumUrl, 'ssl://electrum.example:50002');
      expect(model.fetchConcurrencyFactor, 4);
      expect(model.matchConcurrencyFactor, 3);
    });
  });

  test('an entity survives toModel then toEntity unchanged', () {
    final entity = SpBackendConfig(
      network: BitcoinNetwork.testnet,
      blindbitUrl: 'http://blindbit.example',
      electrumUrl: 'tcp://electrum.example:50001',
      fetchConcurrencyFactor: 16,
      matchConcurrencyFactor: 4,
    );

    expect(
      SpBackendConfigMapper.toEntity(SpBackendConfigMapper.toModel(entity)),
      entity,
    );
  });
}
