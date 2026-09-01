import 'dart:async';

import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart' as core;
import 'package:bull_recoverbull/src/domain/usecases/verify_decrypted_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/recoverbull_bloc_harness.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(MockEncryptedVault());
    registerFallbackValue(const DecryptedVault());
  });
  setUp(setUpRecoverBullBloc);
  tearDown(tearDownRecoverBullBloc);

  test('maps external failure while fetching and does not decrypt', () async {
    final vault = MockEncryptedVault();
    when(() => fetchKey.execute(vault: vault, password: 'pw')).thenAnswer(
      (_) async => const Err(core.ExternalTorProxyUnavailableFailure()),
    );
    final bloc = buildBloc(
      flow: RecoverBullFlow.recoverVault,
      preSelectedVault: vault,
    );
    addTearDown(bloc.close);

    bloc.add(const OnVaultPasswordSet(password: 'pw'));
    await pumpEventQueue();

    expect(bloc.state.failure, isA<ExternalTorProxyUnavailableFailure>());
    expect(bloc.state.vaultKey, isNull);
    verifyNever(
      () => decrypt.execute(
        vault: any(named: 'vault'),
        vaultKey: any(named: 'vaultKey'),
      ),
    );
  });

  test(
    'closing while fetching prevents decrypt, restore, emit, and callback',
    () async {
      final pending = Completer<Result<String, core.RecoverBullFailure>>();
      final vault = MockEncryptedVault();
      when(
        () => fetchKey.execute(vault: vault, password: 'pw'),
      ).thenAnswer((_) => pending.future);
      var walletUpdated = false;
      final bloc = buildBloc(
        flow: RecoverBullFlow.recoverVault,
        preSelectedVault: vault,
        onWalletUpdated: () async => walletUpdated = true,
      );

      bloc.add(const OnVaultPasswordSet(password: 'pw'));
      await pumpEventQueue();
      final beforeClose = bloc.state;
      final closing = bloc.close();
      pending.complete(const Ok('vault-key'));
      await closing;
      await pumpEventQueue();

      verifyNever(
        () => decrypt.execute(
          vault: any(named: 'vault'),
          vaultKey: any(named: 'vaultKey'),
        ),
      );
      expect(walletUpdated, isFalse);
      expect(bloc.state, same(beforeClose));
    },
  );

  test(
    'test flow verifies lifecycle without invoking the wallet callback',
    () async {
      final vault = MockEncryptedVault();
      final decrypted = DecryptedVault(mnemonic: const ['abandon']);
      var walletUpdated = false;
      when(
        () => fetchKey.execute(vault: vault, password: 'pw'),
      ).thenAnswer((_) async => const Ok('vault-key'));
      when(
        () => decrypt.execute(vault: vault, vaultKey: 'vault-key'),
      ).thenReturn(Ok(decrypted));
      final bloc = buildBloc(
        flow: RecoverBullFlow.testVault,
        preSelectedVault: vault,
        onWalletUpdated: () async => walletUpdated = true,
      );

      bloc.add(const OnVaultPasswordSet(password: 'pw'));
      await pumpEventQueue();

      expect(walletUpdated, isFalse);
      verify(() => lifecycle.markVerified()).called(1);
      verifyNever(
        () => restore.execute(decryptedVault: any(named: 'decryptedVault')),
      );
      await bloc.close();
    },
  );

  test('drops concurrent decryption events', () async {
    final verified = Completer<void>();
    final vault = MockEncryptedVault();
    final decrypted = DecryptedVault(mnemonic: const ['abandon']);
    when(
      () => decrypt.execute(
        vault: vault,
        vaultKey: any(named: 'vaultKey'),
      ),
    ).thenReturn(Ok(decrypted));
    when(() => lifecycle.markVerified()).thenAnswer((_) => verified.future);
    final bloc = buildBloc(
      flow: RecoverBullFlow.testVault,
      preSelectedVault: vault,
    );

    bloc.add(const OnVaultDecryption(vaultKey: 'one'));
    await pumpEventQueue();
    bloc.add(const OnVaultDecryption(vaultKey: 'two'));
    await pumpEventQueue();
    verify(() => decrypt.execute(vault: vault, vaultKey: 'one')).called(1);
    verifyNever(() => decrypt.execute(vault: vault, vaultKey: 'two'));

    verified.complete();
    await pumpEventQueue();
    await bloc.close();
  });

  test('recovery marks the restored encrypted backup verified', () async {
    final vault = MockEncryptedVault();
    final decrypted = DecryptedVault(mnemonic: const ['abandon']);
    var walletUpdated = false;
    when(
      () => fetchKey.execute(vault: vault, password: 'pw'),
    ).thenAnswer((_) async => const Ok('vault-key'));
    when(
      () => decrypt.execute(vault: vault, vaultKey: 'vault-key'),
    ).thenReturn(Ok(decrypted));
    when(
      () => restore.execute(decryptedVault: decrypted),
    ).thenAnswer((_) async => const Ok(null));
    final bloc = buildBloc(
      flow: RecoverBullFlow.recoverVault,
      preSelectedVault: vault,
      onWalletUpdated: () async => walletUpdated = true,
    );

    bloc.add(const OnVaultPasswordSet(password: 'pw'));
    await pumpEventQueue();

    verify(() => lifecycle.markVerified()).called(1);
    expect(walletUpdated, isTrue);
    await bloc.close();
  });

  test(
    'fresh recovery restores before marking the lifecycle verified',
    () async {
      final vault = MockEncryptedVault();
      final decrypted = DecryptedVault(mnemonic: const ['abandon']);
      final restoreStarted = Completer<void>();
      final allowRestore = Completer<Result<Null, core.RecoverBullFailure>>();
      final effects = <String>[];
      when(
        () => decrypt.execute(vault: vault, vaultKey: 'vault-key'),
      ).thenReturn(Ok(decrypted));
      when(() => restore.execute(decryptedVault: decrypted)).thenAnswer((
        _,
      ) async {
        effects.add('restore');
        restoreStarted.complete();
        return allowRestore.future;
      });
      when(() => verifyVault.execute(decryptedVault: decrypted)).thenAnswer(
        (_) async => const Ok(VaultVerificationResult.noCurrentWallet),
      );
      when(() => lifecycle.markVerified()).thenAnswer((_) async {
        effects.add('verified');
      });
      final bloc = buildBloc(
        flow: RecoverBullFlow.recoverVault,
        preSelectedVault: vault,
      );

      bloc.add(const OnVaultDecryption(vaultKey: 'vault-key'));
      await restoreStarted.future;
      expect(effects, ['restore']);
      allowRestore.complete(const Ok(null));
      await pumpEventQueue();

      expect(effects, ['restore', 'verified']);
      expect(bloc.state.isFlowFinished, isTrue);
      await bloc.close();
    },
  );
  test('mismatched vault does not mark the current backup verified', () async {
    final verifier = MockVerifyVault();
    final vault = MockEncryptedVault();
    final decrypted = const DecryptedVault(masterFingerprint: 'another-wallet');
    when(
      () => decrypt.execute(vault: vault, vaultKey: 'vault-key'),
    ).thenReturn(Ok(decrypted));
    when(
      () => verifier.execute(decryptedVault: decrypted),
    ).thenAnswer((_) async => const Ok(VaultVerificationResult.mismatch));
    final bloc = buildBloc(
      flow: RecoverBullFlow.recoverVault,
      preSelectedVault: vault,
      verifyDecryptedVaultUsecase: verifier,
    );

    bloc.add(const OnVaultDecryption(vaultKey: 'vault-key'));
    await pumpEventQueue();

    verifyNever(() => lifecycle.markVerified());
    verifyNever(
      () => restore.execute(decryptedVault: any(named: 'decryptedVault')),
    );
    expect(bloc.state.isFlowFinished, isFalse);
    await bloc.close();
  });
}
