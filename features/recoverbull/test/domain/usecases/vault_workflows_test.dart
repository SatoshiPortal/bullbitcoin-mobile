import 'dart:async';

import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_and_store_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/decrypt_and_accept_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_recovery_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_vault_to_provider_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/verify_decrypted_vault_usecase.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../support/log_sink.dart';
import '../../support/recoverbull_bloc_harness.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(fixtureVault());
    registerFallbackValue(DecryptedVault());
  });
  setUp(setUpRecoverBullBloc);
  tearDown(tearDownRecoverBullBloc);

  CreateAndStoreVaultUsecase secure() => CreateAndStoreVaultUsecase(
    log: const TestLogSink(),
    create: createVault,
    check: checkConnection,
    storeKey: storeKey,
    save: SaveVaultToProviderUsecase(
      log: const TestLogSink(),
      saveFile: saveFile,
      connectDrive: connectDrive,
      saveDrive: saveDrive,
    ),
  );

  DecryptAndAcceptVaultUsecase accept({Future<void> Function()? updated}) =>
      DecryptAndAcceptVaultUsecase(
        log: const TestLogSink(),
        fetch: fetchKey,
        decrypt: decrypt,
        verify: verifyVault,
        lifecycle: lifecycle,
        recover: CompleteVaultRecoveryUsecase(
          log: const TestLogSink(),
          restore: restore,
          lifecycle: lifecycle,
          onWalletUpdated: updated,
        ),
      );

  test(
    'failed provider save retries the same encrypted vault without storing twice',
    () async {
      final vault = fixtureVault();
      when(createVault.execute).thenAnswer(
        (_) async => Ok((
          vault: vault,
          vaultKey: 'key',
          network: RecoverBullNetwork.mainnet,
        )),
      );
      when(
        () => storeKey.execute(
          password: 'password',
          vault: vault,
          vaultKey: 'key',
        ),
      ).thenAnswer((_) async => const Ok(null));
      var saves = 0;
      when(() => saveFile.execute(vault: vault)).thenAnswer(
        (_) async => ++saves == 1
            ? const Err(RecoverBullUnexpectedFailure('save failed'))
            : const Ok(null),
      );
      final workflow = secure();
      expect(
        await workflow.execute(
          provider: VaultProvider.customLocation,
          password: 'password',
        ),
        isA<Err>(),
      );
      expect(workflow.hasPendingProviderSave, isTrue);
      final result = await workflow.execute(
        provider: VaultProvider.customLocation,
      );
      expect(result, isA<Ok>());
      expect(workflow.hasPendingProviderSave, isFalse);
      verify(createVault.execute).called(1);
      verify(
        () => storeKey.execute(
          password: 'password',
          vault: vault,
          vaultKey: 'key',
        ),
      ).called(1);
    },
  );

  test('closing during creation prevents any key-server write', () async {
    final pending =
        Completer<
          Result<
            ({
              EncryptedVault vault,
              String vaultKey,
              RecoverBullNetwork network,
            }),
            RecoverBullFailure
          >
        >();
    when(createVault.execute).thenAnswer((_) => pending.future);
    final workflow = secure();
    final result = workflow.execute(
      provider: VaultProvider.customLocation,
      password: 'password',
    );
    workflow.close();
    pending.complete(
      Ok((
        vault: fixtureVault(),
        vaultKey: 'key',
        network: RecoverBullNetwork.mainnet,
      )),
    );
    expect(await result, isA<Err>());
    verifyNever(
      () => storeKey.execute(
        password: any(named: 'password'),
        vault: any(named: 'vault'),
        vaultKey: any(named: 'vaultKey'),
      ),
    );
  });

  test('an already cancelled recovery never fetches a key', () async {
    final vault = fixtureVault();
    when(
      () => fetchKey.execute(vault: vault, password: 'password'),
    ).thenAnswer((_) async => const Ok('key'));
    final result = await accept().execute(
      flow: RecoverBullFlow.recoverVault,
      vault: vault,
      password: 'password',
      cancelled: () => true,
    );
    expect(result, isA<Err>());
    verifyNever(() => fetchKey.execute(vault: vault, password: 'password'));
  });

  test('an already cancelled reveal never decrypts or returns a key', () async {
    final vault = fixtureVault();
    when(
      () => decrypt.execute(vault: vault, vaultKey: 'key'),
    ).thenReturn(Ok(DecryptedVault()));
    final result = await accept().execute(
      flow: RecoverBullFlow.viewVaultKey,
      vault: vault,
      vaultKey: 'key',
      cancelled: () => true,
    );
    expect(result, isA<Err>());
    verifyNever(() => decrypt.execute(vault: vault, vaultKey: 'key'));
  });

  test('cancellation during test lifecycle never completes the flow', () async {
    final vault = fixtureVault();
    final secret = DecryptedVault();
    final marked = Completer<void>();
    when(
      () => decrypt.execute(vault: vault, vaultKey: 'key'),
    ).thenReturn(Ok(secret));
    when(() => verifyVault.execute(decryptedVault: secret)).thenAnswer(
      (_) async => const Ok((
        result: VaultVerificationResult.match,
        network: RecoverBullNetwork.mainnet,
      )),
    );
    when(() => lifecycle.markVerified(any())).thenAnswer((_) => marked.future);
    var cancelled = false;
    final result = accept().execute(
      flow: RecoverBullFlow.testVault,
      vault: vault,
      vaultKey: 'key',
      cancelled: () => cancelled,
    );
    await pumpEventQueue();
    verify(() => lifecycle.markVerified(RecoverBullNetwork.mainnet)).called(1);
    cancelled = true;
    marked.complete();
    expect(await result, isA<Err>());
    verifyNever(
      () => restore.execute(decryptedVault: any(named: 'decryptedVault')),
    );
  });

  test('wallet mismatch never restores or updates verified status', () async {
    final vault = fixtureVault();
    final secret = DecryptedVault();
    when(
      () => decrypt.execute(vault: vault, vaultKey: 'key'),
    ).thenReturn(Ok(secret));
    when(() => verifyVault.execute(decryptedVault: secret)).thenAnswer(
      (_) async => const Ok((
        result: VaultVerificationResult.mismatch,
        network: RecoverBullNetwork.mainnet,
      )),
    );
    expect(
      await accept().execute(
        flow: RecoverBullFlow.recoverVault,
        vault: vault,
        vaultKey: 'key',
        cancelled: () => false,
      ),
      isA<Err>().having(
        (value) => value.failure,
        'failure',
        isA<VaultBelongsToAnotherWalletFailure>(),
      ),
    );
    verifyNever(
      () => restore.execute(decryptedVault: any(named: 'decryptedVault')),
    );
    verifyNever(() => lifecycle.markVerified(any()));
  });

  test(
    'revealing a valid key does not restore or mutate wallet status',
    () async {
      final vault = fixtureVault();
      when(
        () => decrypt.execute(vault: vault, vaultKey: 'key'),
      ).thenReturn(Ok(DecryptedVault()));
      final result = await accept().execute(
        flow: RecoverBullFlow.viewVaultKey,
        vault: vault,
        vaultKey: 'key',
        cancelled: () => false,
      );
      expect(
        result,
        isA<Ok>().having(
          (value) => (value.value as AcceptedVault).revealedKey,
          'revealed key',
          'key',
        ),
      );
      verifyNever(
        () => verifyVault.execute(decryptedVault: any(named: 'decryptedVault')),
      );
      verifyNever(
        () => restore.execute(decryptedVault: any(named: 'decryptedVault')),
      );
      expect(result.toString(), isNot(contains('key: key')));
    },
  );

  test('closing after key fetch prevents plaintext decryption', () async {
    final vault = fixtureVault();
    final pending = Completer<Result<String, RecoverBullFailure>>();
    when(
      () => fetchKey.execute(vault: vault, password: 'password'),
    ).thenAnswer((_) => pending.future);
    var cancelled = false;
    final result = accept().execute(
      flow: RecoverBullFlow.recoverVault,
      vault: vault,
      password: 'password',
      cancelled: () => cancelled,
    );
    cancelled = true;
    pending.complete(const Ok('key'));
    expect(await result, isA<Err>());
    verifyNever(
      () => decrypt.execute(
        vault: any(named: 'vault'),
        vaultKey: any(named: 'vaultKey'),
      ),
    );
  });

  test(
    'successful restore survives advisory lifecycle and refresh failures',
    () async {
      final secret = DecryptedVault();
      when(
        () => restore.execute(decryptedVault: secret),
      ).thenAnswer((_) async => const Ok(RecoverBullNetwork.mainnet));
      when(
        () => lifecycle.markVerified(any()),
      ).thenThrow(Exception('private detail'));
      final workflow = CompleteVaultRecoveryUsecase(
        log: const TestLogSink(),
        restore: restore,
        lifecycle: lifecycle,
        onWalletUpdated: () async => throw Exception('private detail'),
      );
      expect(
        await workflow.execute(vault: secret, cancelled: () => false),
        isA<Ok>(),
      );
    },
  );
}
