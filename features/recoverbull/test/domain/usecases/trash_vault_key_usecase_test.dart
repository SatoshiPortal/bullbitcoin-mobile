import 'dart:io';

import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import '../../support/log_sink.dart';
import 'package:bull_recoverbull/src/domain/usecases/trash_vault_key_usecase.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:recoverbull/recoverbull.dart' as sdk;

class _Repository extends Mock implements RecoverBullRepository {}

class _Ensure extends Mock implements EnsureRecoverBullTorSessionUsecase {}

RecoverBullTorRoute _route({Future<void> Function()? onClose}) =>
    RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
      ),
      onClose ?? () async {},
      HttpClient(),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_route());
  });

  test('trash preserves Ok when owned route teardown throws', () async {
    var closed = false;
    final route = _route(
      onClose: () async {
        closed = true;
        throw StateError('teardown');
      },
    );
    final repository = _Repository();
    final ensure = _Ensure();
    final backup = sdk.RecoverBull.createBackup(
      secret: [1],
      backupKey: List<int>.filled(32, 1),
    );
    final vault = EncryptedVault(file: backup.toJson());
    when(() => ensure.execute()).thenAnswer((_) async => Ok(route));
    when(
      () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenAnswer(
      (_) async =>
          const Ok(VaultKeyFetchResult(vaultKey: 'key', attemptStatus: null)),
    );

    final result = await TrashVaultKeyUsecase(
      repository: repository,
      ensureSession: ensure,
      log: const TestLogSink(),
    ).execute(vault: vault, password: 'password');

    expect(result, isA<Ok<VaultKeyFetchResult, RecoverBullFailure>>());
    expect(closed, isTrue);
  });

  test('trash closes its owned route when repository throws', () async {
    var closed = false;
    final route = _route(onClose: () async => closed = true);
    final repository = _Repository();
    final ensure = _Ensure();
    final backup = sdk.RecoverBull.createBackup(
      secret: [1],
      backupKey: List<int>.filled(32, 1),
    );
    final vault = EncryptedVault(file: backup.toJson());
    when(() => ensure.execute()).thenAnswer((_) async => Ok(route));
    when(
      () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenThrow(StateError('repository'));

    await expectLater(
      () => TrashVaultKeyUsecase(
        repository: repository,
        ensureSession: ensure,
        log: const TestLogSink(),
      ).execute(vault: vault, password: 'password'),
      throwsStateError,
    );
    expect(closed, isTrue);
  });
}
