import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/sp/data/key_value_sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../sp_fakes.dart';

void main() {
  group('KeyValueSpBackendConfigRepository storage boundary', () {
    KeyValueSpBackendConfigRepository build(
      KeyValueStorageDatasource<String> storage,
    ) => KeyValueSpBackendConfigRepository(storage: storage);

    SpBackendConfig config() => SpBackendConfig(
      network: BitcoinNetwork.regtest,
      blindbitUrl: 'http://blindbit.example',
      electrumUrl: 'tcp://electrum.example:50001',
    );

    test('fetch returns Err when the storage read throws', () async {
      final result = await build(ThrowingKeyValueStorage()).fetch();

      final failure = (result as Err<SpBackendConfig?, SpFailure>).failure;
      expect(failure, isA<SpUnexpected>());
      expect(failure.logMessage, contains('SP backend config read failed'));
    });

    test('save returns Err when the storage write throws', () async {
      final result = await build(ThrowingKeyValueStorage()).save(config());

      final failure = (result as Err<void, SpFailure>).failure;
      expect(failure, isA<SpUnexpected>());
      expect(failure.logMessage, contains('SP backend config save failed'));
    });

    test('delete returns Err when the storage delete throws', () async {
      final result = await build(ThrowingKeyValueStorage()).delete();

      final failure = (result as Err<void, SpFailure>).failure;
      expect(failure, isA<SpUnexpected>());
      expect(failure.logMessage, contains('SP backend config delete failed'));
    });

    test('fetch reports corrupt stored json as SpConfigInvalid', () async {
      final storage = InMemoryKeyValueStorage();
      await storage.saveValue(key: 'sp_backend_config', value: 'not json');

      final result = await build(storage).fetch();

      final failure = (result as Err<SpBackendConfig?, SpFailure>).failure;
      expect(failure, isA<SpConfigInvalid>());
    });

    test('fetchOrNull folds a corrupt config to absent but keeps a read '
        'failure as Err', () async {
      // Setup overwrites a corrupt config, so it reads as absent. A keystore
      // that cannot be read is not the same as "no wallet".
      final storage = InMemoryKeyValueStorage();
      await storage.saveValue(key: 'sp_backend_config', value: 'not json');

      expect(
        (await build(storage).fetchOrNull() as Ok<SpBackendConfig?, SpFailure>)
            .value,
        isNull,
      );
      expect(
        await build(ThrowingKeyValueStorage()).fetchOrNull(),
        isA<Err<SpBackendConfig?, SpFailure>>(),
      );
    });

    test('save then fetch round-trips the config', () async {
      final repo = build(InMemoryKeyValueStorage());

      expect(await repo.save(config()), isA<Ok<void, SpFailure>>());
      final result = await repo.fetch();

      expect((result as Ok<SpBackendConfig?, SpFailure>).value, config());
    });
  });
}
