import 'dart:async';

import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart' as core;
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/trash_vault_key_usecase.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../support/log_sink.dart';
import '../support/recoverbull_bloc_harness.dart';

const _password = 'abandoned-vault-password';

class _Repository extends Mock implements RecoverBullRepository {}

class _Ensure extends Mock implements EnsureRecoverBullTorSessionUsecase {}

/// The server key of an abandoned vault is trashed only when no provider save
/// was ever started for it: a save that reported an error may still have
/// landed, and trashing its key would make that backup undecryptable.
void main() {
  late _Repository repository;
  late TrashVaultKeyUsecase trash;

  setUpAll(() {
    registerFallbackValue(fixtureVault());
    registerFallbackValue(const DecryptedVault());
    registerFallbackValue(testRoute());
  });
  setUp(() async {
    await setUpRecoverBullBloc();
    repository = _Repository();
    final ensure = _Ensure();
    when(() => ensure.execute()).thenAnswer((_) async => Ok(testRoute()));
    when(
      () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenAnswer(
      (_) async =>
          const Ok(VaultKeyFetchResult(vaultKey: 'key', attemptStatus: null)),
    );
    trash = TrashVaultKeyUsecase(
      repository: repository,
      ensureSession: ensure,
      log: const TestLogSink(),
    );
  });
  tearDown(tearDownRecoverBullBloc);

  void storesKeyFor(EncryptedVault vault) {
    when(() => createVault.execute()).thenAnswer(
      (_) async => Ok((
        vault: vault,
        vaultKey: 'key',
        network: RecoverBullNetwork.mainnet,
      )),
    );
    when(
      () =>
          storeKey.execute(password: _password, vault: vault, vaultKey: 'key'),
    ).thenAnswer((_) async => const Ok(null));
  }

  void savesFile(Future<Result<Null, core.RecoverBullFailure>> Function() r) {
    when(
      () => saveFile.execute(
        content: any(named: 'content'),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer((_) => r());
  }

  void create(RecoverBullBloc bloc) => bloc.add(
    OnVaultCreation(
      provider: VaultProvider.customLocation,
      password: _password,
    ),
  );

  void verifyTrashed(EncryptedVault vault) => verify(
    () => repository.trashVaultKeyWithStatus(
      vault.id,
      _password,
      vault.salt,
      any(),
    ),
  ).called(1);

  void verifyNotTrashed() => verifyNever(
    () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
  );

  test('a failed provider save never trashes the key on close', () async {
    final vault = fixtureVault();
    storesKeyFor(vault);
    savesFile(() async => const Err(core.RecoverBullUnexpectedFailure()));
    final bloc = buildBloc(
      flow: RecoverBullFlow.secureVault,
      trashVaultKeyUsecase: trash,
    );

    create(bloc);
    await pumpEventQueue();
    expect(bloc.hasPendingProviderSave, isTrue);
    expect(bloc.state.vaultPassword, isNull);
    await bloc.close();
    await pumpEventQueue();

    // The save may have landed despite the error; an orphan key is harmless,
    // an undecryptable backup is not.
    verifyNotTrashed();
  });

  test('a retried save that succeeds keeps the key on the server', () async {
    final vault = fixtureVault();
    storesKeyFor(vault);
    savesFile(() async => const Err(core.RecoverBullUnexpectedFailure()));
    final bloc = buildBloc(
      flow: RecoverBullFlow.secureVault,
      trashVaultKeyUsecase: trash,
    );

    create(bloc);
    await pumpEventQueue();
    savesFile(() async => const Ok(null));
    bloc.add(
      const OnVaultProviderSelection(provider: VaultProvider.customLocation),
    );
    await pumpEventQueue();
    expect(bloc.hasPendingProviderSave, isFalse);
    await bloc.close();
    await pumpEventQueue();

    verifyNotTrashed();
  });

  test(
    'closing while a save is in flight keeps the key if the save lands',
    () async {
      final vault = fixtureVault();
      final save = Completer<Result<Null, core.RecoverBullFailure>>();
      storesKeyFor(vault);
      savesFile(() => save.future);
      final bloc = buildBloc(
        flow: RecoverBullFlow.secureVault,
        trashVaultKeyUsecase: trash,
      );

      create(bloc);
      await pumpEventQueue();
      final closing = bloc.close();
      await pumpEventQueue();
      verifyNotTrashed();
      save.complete(const Ok(null));
      await closing;
      await pumpEventQueue();

      verifyNotTrashed();
    },
  );

  test(
    'closing while a save is in flight keeps the key if the save fails',
    () async {
      final vault = fixtureVault();
      final save = Completer<Result<Null, core.RecoverBullFailure>>();
      storesKeyFor(vault);
      savesFile(() => save.future);
      final bloc = buildBloc(
        flow: RecoverBullFlow.secureVault,
        trashVaultKeyUsecase: trash,
      );

      create(bloc);
      await pumpEventQueue();
      final closing = bloc.close();
      save.complete(const Err(core.RecoverBullUnexpectedFailure()));
      await closing;
      await pumpEventQueue();

      verifyNotTrashed();
    },
  );

  test(
    'closing while the key is being stored trashes it once stored',
    () async {
      final vault = fixtureVault();
      final stored = Completer<Result<Null, core.RecoverBullFailure>>();
      when(() => createVault.execute()).thenAnswer(
        (_) async => Ok((
          vault: vault,
          vaultKey: 'key',
          network: RecoverBullNetwork.mainnet,
        )),
      );
      when(
        () => storeKey.execute(
          password: _password,
          vault: vault,
          vaultKey: 'key',
        ),
      ).thenAnswer((_) => stored.future);
      final bloc = buildBloc(
        flow: RecoverBullFlow.secureVault,
        trashVaultKeyUsecase: trash,
      );

      create(bloc);
      await pumpEventQueue();
      final closing = bloc.close();
      stored.complete(const Ok(null));
      await closing;
      await pumpEventQueue();

      verifyTrashed(vault);
      verifyNever(
        () => saveFile.execute(
          content: any(named: 'content'),
          filename: any(named: 'filename'),
        ),
      );
    },
  );

  test('a failing trash neither blocks closing nor logs secrets', () async {
    final vault = fixtureVault();
    final log = TestLogSink.recording();
    final stored = Completer<Result<Null, core.RecoverBullFailure>>();
    when(() => createVault.execute()).thenAnswer(
      (_) async => Ok((
        vault: vault,
        vaultKey: 'key',
        network: RecoverBullNetwork.mainnet,
      )),
    );
    when(
      () =>
          storeKey.execute(password: _password, vault: vault, vaultKey: 'key'),
    ).thenAnswer((_) => stored.future);
    when(
      () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenThrow(StateError('server down'));
    final bloc = buildBloc(
      flow: RecoverBullFlow.secureVault,
      log: log,
      trashVaultKeyUsecase: trash,
    );

    create(bloc);
    await pumpEventQueue();
    final closing = bloc.close();
    stored.complete(const Ok(null));
    await closing;
    await pumpEventQueue();

    final messages = log.entries.map((entry) => entry.message).join('\n');
    expect(messages, contains('recoverbull.vault.abandoned_key_trash'));
    expect(messages, isNot(contains(vault.id)));
    expect(messages, isNot(contains(_password)));
  });
}
