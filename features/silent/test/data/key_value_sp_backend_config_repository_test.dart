import 'package:silent/src/data/key_value_sp_backend_config_repository.dart';
import 'package:silent/src/domain/entities/sp_backend_config.dart';
import 'package:silent/src/domain/repositories/sp_backend_config_repository.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart';

import '../sp_fakes.dart';

void main() {
  group('KeyValueSpBackendConfigRepository storage boundary', () {
    KeyValueSpBackendConfigRepository build(
      FakeSecureStoragePlatform storage,
    ) => KeyValueSpBackendConfigRepository(storage: spKeychain(storage));

    SpBackendConfig config() => SpBackendConfig(
      network: BitcoinNetwork.regtest,
      blindbitUrl: 'http://blindbit.example',
      electrumUrl: 'tcp://electrum.example:50001',
    );

    test('fetch returns Err when the storage read throws', () async {
      final result = await build(
        FakeSecureStoragePlatform(locked: true, writesFail: true),
      ).fetch();

      final failure = (result as Err<SpBackendConfig?, SilentFailure>).failure;
      expect(failure, isA<SilentUnexpected>());
      expect(failure.logMessage, contains('SP backend config read failed'));
    });

    test('save returns Err when the storage write throws', () async {
      final result = await build(
        FakeSecureStoragePlatform(locked: true, writesFail: true),
      ).save(config());

      final failure = (result as Err<void, SilentFailure>).failure;
      expect(failure, isA<SilentUnexpected>());
      expect(failure.logMessage, contains('SP backend config save failed'));
    });

    test('delete returns Err when the storage delete throws', () async {
      final result = await build(
        FakeSecureStoragePlatform(locked: true, writesFail: true),
      ).delete();

      final failure = (result as Err<void, SilentFailure>).failure;
      expect(failure, isA<SilentUnexpected>());
      expect(failure.logMessage, contains('SP backend config delete failed'));
    });

    test('fetch reports corrupt stored json as SilentConfigInvalid', () async {
      final storage = FakeSecureStoragePlatform();
      storage.entries['sp_backend_config'] = 'not json';

      final result = await build(storage).fetch();

      final failure = (result as Err<SpBackendConfig?, SilentFailure>).failure;
      expect(failure, isA<SilentConfigInvalid>());
    });

    test('fetchOrNull folds a corrupt config to absent but keeps a read '
        'failure as Err', () async {
      // Setup overwrites a corrupt config, so it reads as absent. A keystore
      // that cannot be read is not the same as "no wallet".
      final storage = FakeSecureStoragePlatform();
      storage.entries['sp_backend_config'] = 'not json';

      expect(
        (await build(storage).fetchOrNull()
                as Ok<SpBackendConfig?, SilentFailure>)
            .value,
        isNull,
      );
      expect(
        await build(FakeSecureStoragePlatform(locked: true, writesFail: true))
            .fetchOrNull(),
        isA<Err<SpBackendConfig?, SilentFailure>>(),
      );
    });

    test('save then fetch round-trips the config', () async {
      final repo = build(FakeSecureStoragePlatform());

      expect(await repo.save(config()), isA<Ok<void, SilentFailure>>());
      final result = await repo.fetch();

      expect((result as Ok<SpBackendConfig?, SilentFailure>).value, config());
    });
  });
}
