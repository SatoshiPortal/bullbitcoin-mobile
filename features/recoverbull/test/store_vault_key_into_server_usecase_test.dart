import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'dart:io';

import 'package:bull_tor/tor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

final class _Repository extends Mock implements RecoverBullRepository {}

final class _EnsureTor extends Mock
    implements EnsureRecoverBullTorSessionUsecase {}

final class _Vault extends Mock implements EncryptedVault {}

void main() {
  late _Repository repository;
  late RecoverBullDatabase database;
  late RecoverBullAttemptMonitoringStore attemptMonitoringStore;
  late _Vault vault;
  late RecoverBullTorRoute route;

  setUp(() async {
    repository = _Repository();
    database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    attemptMonitoringStore = RecoverBullAttemptMonitoringStore(database);
    vault = _Vault();
    route = RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.direct,
      ),
      () async {},
      HttpClient(),
    );
    when(() => vault.id).thenReturn('00');
    when(() => vault.salt).thenReturn('11');
  });

  tearDown(() => database.close());

  StoreVaultKeyIntoServerUsecase buildUsecase() =>
      StoreVaultKeyIntoServerUsecase(repository, _EnsureTor());

  test(
    'successful store returns success without local attempt monitoring',
    () async {
      when(
        () => repository.storeVaultKey('00', 'password', '11', 'key', route),
      ).thenAnswer((_) async => const Ok(null));

      final result = await buildUsecase().execute(
        password: 'password',
        vault: vault,
        vaultKey: 'key',
        route: route,
      );

      expect(result, isA<Ok>());
      expect(await attemptMonitoringStore.monitoredBackups(), isEmpty);
    },
  );

  test('failed store does not register the backup', () async {
    when(
      () => repository.storeVaultKey('00', 'password', '11', 'key', route),
    ).thenAnswer((_) async => const Err(KeyServerUnavailableFailure()));

    final result = await buildUsecase().execute(
      password: 'password',
      vault: vault,
      vaultKey: 'key',
      route: route,
    );

    expect(result, isA<Err>());
    expect(await attemptMonitoringStore.monitoredBackups(), isEmpty);
  });
}
