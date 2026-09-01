import 'dart:async';
import 'dart:io';

import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/ports.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart' as core;
import 'package:bull_recoverbull/src/domain/usecases/check_server_connection_usecase.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/verify_decrypted_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/register_monitored_backup_usecase.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/domain/usecases/connect_to_key_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/presentation_failure.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';
import 'package:drift/native.dart';

class _MockPickVault extends Mock implements PickVaultUsecase {}

class _MockSaveFile extends Mock implements SaveFileToSystemUsecase {}

class _MockCreateVault extends Mock implements CreateEncryptedVaultUsecase {}

class _MockStoreKey extends Mock implements StoreVaultKeyIntoServerUsecase {}

class _MockCheckConnection extends Mock
    implements CheckServerConnectionUsecase {}

class _MockFetchKey extends Mock implements FetchVaultKeyFromServerUsecase {}

class _MockDecrypt extends Mock implements DecryptVaultUsecase {}

class _MockRestore extends Mock implements RestoreVaultUsecase {}

class _MockConnectDrive extends Mock implements ConnectToGoogleDriveUsecase {}

class _MockSaveDrive extends Mock implements SaveVaultToGoogleDriveUsecase {}

class _MockEnsureRecoverBullTorSession extends Mock
    implements EnsureRecoverBullTorSessionUsecase {}

class _MockFetchLatestDrive extends Mock
    implements FetchLatestGoogleDriveVaultUsecase {}

class _MockWatchTorConnection extends Mock
    implements WatchTorConnectionUsecase {}

class _MockLifecycle extends Mock implements RecoverBullLifecyclePort {}

class _MockVerifyVault extends Mock implements VerifyDecryptedVaultUsecase {}

class _MockEncryptedVault extends Mock implements EncryptedVault {}

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
  late _MockPickVault pickVault;
  late _MockSaveFile saveFile;
  late _MockCreateVault createVault;
  late _MockStoreKey storeKey;
  late _MockCheckConnection checkConnection;
  late _MockFetchKey fetchKey;
  late _MockDecrypt decrypt;
  late _MockRestore restore;
  late _MockConnectDrive connectDrive;
  late _MockSaveDrive saveDrive;
  late _MockEnsureRecoverBullTorSession ensureRecoverBullTorSession;
  late _MockFetchLatestDrive fetchLatestDrive;
  late _MockWatchTorConnection watchTor;
  late _MockLifecycle lifecycle;
  late _MockVerifyVault verifyVault;
  late RecoverBullDatabase database;
  late RecoverBullAttemptMonitoringStore attemptMonitoringStore;

  setUpAll(() {
    registerFallbackValue(_MockEncryptedVault());
    registerFallbackValue(const DecryptedVault());
  });

  setUp(() async {
    database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    attemptMonitoringStore = RecoverBullAttemptMonitoringStore(database);
    pickVault = _MockPickVault();
    saveFile = _MockSaveFile();
    createVault = _MockCreateVault();
    storeKey = _MockStoreKey();
    checkConnection = _MockCheckConnection();
    when(
      () => checkConnection.execute(),
    ).thenAnswer((_) async => const Ok(true));
    fetchKey = _MockFetchKey();
    decrypt = _MockDecrypt();
    restore = _MockRestore();
    connectDrive = _MockConnectDrive();
    saveDrive = _MockSaveDrive();
    ensureRecoverBullTorSession = _MockEnsureRecoverBullTorSession();
    when(
      () => ensureRecoverBullTorSession.execute(
        restartEmbedded: any(named: 'restartEmbedded'),
      ),
    ).thenAnswer((_) async => const Err(core.KeyServerUnavailableFailure()));
    fetchLatestDrive = _MockFetchLatestDrive();
    watchTor = _MockWatchTorConnection();
    lifecycle = _MockLifecycle();
    verifyVault = _MockVerifyVault();
    when(
      () => verifyVault.execute(decryptedVault: any(named: 'decryptedVault')),
    ).thenAnswer((_) async => const Ok(VaultVerificationResult.match));
    when(() => lifecycle.markStored()).thenAnswer((_) async {});
    when(() => lifecycle.markVerified()).thenAnswer((_) async {});
    when(
      () => watchTor.execute(),
    ).thenAnswer((_) => const Stream<TorConnectionState>.empty());
  });

  // No event is auto-dispatched, so unstubbed mocks stay untouched unless a
  // test drives the matching flow — the Tor subscription above excepted.
  RecoverBullBloc buildBloc({
    required RecoverBullFlow flow,
    EncryptedVault? preSelectedVault,
    Future<void> Function()? onWalletUpdated,
    VerifyDecryptedVaultUsecase? verifyDecryptedVaultUsecase,
  }) => RecoverBullBloc(
    flow: flow,
    preSelectedVault: preSelectedVault,
    pickVaultUsecase: pickVault,
    saveFileToSystemUsecase: saveFile,
    createEncryptedVaultUsecase: createVault,
    storeVaultKeyIntoServerUsecase: storeKey,
    registerMonitoredBackupUsecase: RegisterMonitoredBackupUsecase(
      attemptMonitoringStore,
    ),
    checkKeyServerConnectionUsecase: checkConnection,
    connectToKeyServerUsecase: ConnectToKeyServerUsecase(
      checkConnection,
      ensureRecoverBullTorSession,
      wait: (_) async {},
    ),
    fetchVaultKeyFromServerUsecase: fetchKey,
    decryptVaultUsecase: decrypt,
    restoreVaultUsecase: restore,
    connectToGoogleDriveUsecase: connectDrive,
    saveToGoogleDriveUsecase: saveDrive,
    ensureRecoverBullTorSessionUsecase: ensureRecoverBullTorSession,
    onWalletUpdated: onWalletUpdated,
    fetchLatestGoogleDriveVaultUsecase: fetchLatestDrive,
    watchTorConnectionUsecase: watchTor,
    lifecycle: lifecycle,
    verifyDecryptedVaultUsecase: verifyDecryptedVaultUsecase ?? verifyVault,
  );

  group('OnVaultPasswordSet guard', () {
    test('no vault set -> VaultNotSetFailure, password not stored, key never '
        'fetched', () async {
      // recoverVault hits the default branch; no preSelectedVault => null.
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

      bloc.add(const OnVaultPasswordSet(password: 'pw'));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<VaultNotSetFailure>());
      // The guard must return before storing the password or fetching the
      // key — proving the early `return` is effective (the pre-fix code fell
      // through to `state.vault!`).
      expect(bloc.state.vaultPassword, isNull);
      verifyNever(
        () => fetchKey.execute(
          vault: any(named: 'vault'),
          password: any(named: 'password'),
        ),
      );

      await bloc.close();
    });

    test('drops concurrent password fetches', () async {
      final pending = Completer<Result<String, core.RecoverBullCoreFailure>>();
      final vault = _MockEncryptedVault();
      when(
        () => fetchKey.execute(
          vault: vault,
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) => pending.future);
      when(
        () => decrypt.execute(vault: vault, vaultKey: 'key'),
      ).thenReturn(const Err(core.RecoverBullUnexpectedCoreFailure()));
      final bloc = buildBloc(
        flow: RecoverBullFlow.recoverVault,
        preSelectedVault: vault,
      );

      bloc.add(const OnVaultPasswordSet(password: 'one'));
      await pumpEventQueue();
      bloc.add(const OnVaultPasswordSet(password: 'two'));
      await pumpEventQueue();
      verify(() => fetchKey.execute(vault: vault, password: 'one')).called(1);
      verifyNever(() => fetchKey.execute(vault: vault, password: 'two'));

      pending.complete(const Ok('key'));
      await pumpEventQueue();
      await bloc.close();
    });
  });

  group('OnVaultProviderSelection (secureVault) guard', () {
    test(
      'no password set -> PasswordNotSetFailure, creation never started',
      () async {
        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();

        // The pre-fix code fell through to `state.vaultPassword!`, which threw and
        // surfaced as a generic RecoverBullUnexpectedFailure. The guard must keep
        // the intended typed failure and never reach vault creation.
        expect(bloc.state.failure, isA<PasswordNotSetFailure>());
        verifyNever(() => createVault.execute());

        await bloc.close();
      },
    );

    test(
      'rejects a password submitted after server storage and never retries storage',
      () async {
        final vault = _MockEncryptedVault();
        when(() => vault.id).thenReturn('00');
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');
        when(
          () => createVault.execute(),
        ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
        when(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer(
          (_) async => const Err(core.RecoverBullUnexpectedCoreFailure()),
        );

        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);
        bloc.add(const OnVaultPasswordSet(password: 'pw'));
        await pumpEventQueue();
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();
        expect(bloc.hasPendingProviderSave, isTrue);

        bloc.add(const OnVaultPasswordSet(password: 'changed-password'));
        await pumpEventQueue();

        expect(bloc.state.failure, isA<VaultProviderSaveFailure>());
        verify(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).called(1);
        verify(() => createVault.execute()).called(1);
        verifyNever(
          () => storeKey.execute(
            password: 'changed-password',
            vault: any(named: 'vault'),
            vaultKey: any(named: 'vaultKey'),
          ),
        );
        await bloc.close();
      },
    );
  });

  tearDown(() => database.close());

  group('OnVaultCreation store-key failure mapping', () {
    test('server failure never calls the provider', () async {
      final vault = _MockEncryptedVault();
      when(
        () => createVault.execute(),
      ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
      when(
        () => checkConnection.execute(),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
      ).thenAnswer((_) async => const Err(core.KeyServerUnavailableFailure()));

      final bloc = buildBloc(flow: RecoverBullFlow.secureVault);
      bloc.add(
        const OnVaultCreation(
          provider: VaultProvider.customLocation,
          password: 'pw',
        ),
      );
      await pumpEventQueue();

      expect(bloc.state.failure, isA<KeyServerConnectionFailure>());
      verifyNever(
        () => saveFile.execute(
          content: any(named: 'content'),
          filename: any(named: 'filename'),
        ),
      );
      await bloc.close();
    });

    test(
      'provider failure can be retried without storing the key again',
      () async {
        final vault = _MockEncryptedVault();
        when(() => vault.id).thenReturn('00');
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');
        when(
          () => createVault.execute(),
        ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer(
          (_) async => const Err(core.KeyServerUnavailableFailure()),
        );
        when(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).thenAnswer((_) async => const Ok(null));
        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        bloc.add(
          const OnVaultCreation(
            provider: VaultProvider.customLocation,
            password: 'pw',
          ),
        );
        await pumpEventQueue();
        expect(bloc.state.failure, isA<VaultProviderSaveFailure>());
        expect(bloc.state.vault, isNull);
        expect(await attemptMonitoringStore.monitoredBackups(), isEmpty);

        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();

        verify(() => createVault.execute()).called(1);
        verify(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).called(1);
        verify(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).called(2);
        expect(bloc.state.vault, same(vault));
        expect(bloc.state.failure, isNull);
        expect(bloc.state.vaultPassword, isNull);
        expect(await attemptMonitoringStore.monitoredBackups(), hasLength(1));
        await bloc.close();
      },
    );

    test(
      'rate-limited storeVaultKey -> VaultRateLimitedFailure (cooldown kept)',
      () async {
        const cooldown = Duration(minutes: 5);
        final vault = _MockEncryptedVault();
        when(() => vault.id).thenReturn('00');
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');

        when(
          () => createVault.execute(),
        ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'deadbeef')));
        when(
          () => checkConnection.execute(),
        ).thenAnswer((_) async => const Ok(true));
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => storeKey.execute(
            password: any(named: 'password'),
            vault: any(named: 'vault'),
            vaultKey: any(named: 'vaultKey'),
          ),
        ).thenAnswer(
          (_) async =>
              Err(const core.KeyServerRateLimitedFailure(retryIn: cooldown)),
        );

        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        // secureVault stores the password, then provider selection triggers
        // creation.
        bloc.add(const OnVaultPasswordSet(password: 'pw'));
        await pumpEventQueue();
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();

        // The 429 cooldown must survive the create path instead of collapsing
        // into the generic VaultCreationFailure.
        expect(bloc.state.failure, isA<VaultRateLimitedFailure>());
        expect(
          (bloc.state.failure as VaultRateLimitedFailure).retryIn,
          cooldown,
        );
        verifyNever(() => lifecycle.markStored());

        await bloc.close();
      },
    );

    test(
      'marks the backup stored after provider and key store succeed',
      () async {
        final vault = _MockEncryptedVault();
        when(() => vault.id).thenReturn('00');
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');
        when(
          () => createVault.execute(),
        ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).thenAnswer((_) async => const Ok(null));
        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        bloc.add(const OnVaultPasswordSet(password: 'pw'));
        await pumpEventQueue();
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();

        expect(bloc.state.failure, isNull);
        verify(() => lifecycle.markStored()).called(1);
        expect(await attemptMonitoringStore.monitoredBackups(), hasLength(1));
        expect(bloc.state.vaultPassword, isNull);
        await bloc.close();
      },
    );

    test('rejects unsupported iCloud before storing the remote key', () async {
      final vault = _MockEncryptedVault();
      when(
        () => createVault.execute(),
      ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
      when(
        () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
      ).thenAnswer((_) async => const Ok(null));
      final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

      bloc.add(
        const OnVaultCreation(provider: VaultProvider.iCloud, password: 'pw'),
      );
      await pumpEventQueue();

      expect(bloc.state.failure, isA<SelectVaultFailure>());
      verifyNever(
        () => storeKey.execute(
          password: any(named: 'password'),
          vault: any(named: 'vault'),
          vaultKey: any(named: 'vaultKey'),
        ),
      );
      verifyNever(() => lifecycle.markStored());
      await bloc.close();
    });

    test(
      'drops concurrent provider selections while creation is in flight',
      () async {
        final creation =
            Completer<
              Result<
                ({EncryptedVault vault, String vaultKey}),
                core.RecoverBullCoreFailure
              >
            >();
        final vault = _MockEncryptedVault();
        when(() => vault.id).thenReturn('00');
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');
        when(() => createVault.execute()).thenAnswer((_) => creation.future);
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).thenAnswer((_) async => const Ok(null));
        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        bloc.add(const OnVaultPasswordSet(password: 'pw'));
        await pumpEventQueue();
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();
        verify(() => createVault.execute()).called(1);

        creation.complete(Ok((vault: vault, vaultKey: 'key')));
        await pumpEventQueue();
        verify(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).called(1);
        verify(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).called(1);
        await bloc.close();
      },
    );

    test('closing during creation prevents external side effects', () async {
      final creation =
          Completer<
            Result<
              ({EncryptedVault vault, String vaultKey}),
              core.RecoverBullCoreFailure
            >
          >();
      final vault = _MockEncryptedVault();
      when(() => createVault.execute()).thenAnswer((_) => creation.future);
      final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

      bloc.add(
        const OnVaultCreation(
          provider: VaultProvider.customLocation,
          password: 'pw',
        ),
      );
      await pumpEventQueue();
      final closing = bloc.close();
      creation.complete(Ok((vault: vault, vaultKey: 'key')));
      await closing;

      verifyNever(
        () => storeKey.execute(
          password: any(named: 'password'),
          vault: any(named: 'vault'),
          vaultKey: any(named: 'vaultKey'),
        ),
      );
      verifyNever(
        () => saveFile.execute(
          content: any(named: 'content'),
          filename: any(named: 'filename'),
        ),
      );
    });
  });

  test('maps external failure while fetching and does not decrypt', () async {
    final vault = _MockEncryptedVault();
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
      final pending = Completer<Result<String, core.RecoverBullCoreFailure>>();
      final vault = _MockEncryptedVault();
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
      final vault = _MockEncryptedVault();
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
    final vault = _MockEncryptedVault();
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
    final vault = _MockEncryptedVault();
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
      final vault = _MockEncryptedVault();
      final decrypted = DecryptedVault(mnemonic: const ['abandon']);
      final restoreStarted = Completer<void>();
      final allowRestore =
          Completer<Result<Null, core.RecoverBullCoreFailure>>();
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

  test('closing a pending route preparation still closes the bloc', () async {
    final preparation =
        Completer<Result<RecoverBullTorRoute, core.RecoverBullCoreFailure>>();
    when(
      () => ensureRecoverBullTorSession.execute(
        restartEmbedded: any(named: 'restartEmbedded'),
      ),
    ).thenAnswer((_) => preparation.future);
    var routeClosed = 0;
    final route = _route(
      onClose: () async {
        routeClosed++;
        throw StateError('teardown');
      },
    );
    final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

    bloc.add(const OnTorInitialization());
    await pumpEventQueue();
    final closing = bloc.close();
    preparation.complete(Ok(route));

    await closing;
    expect(bloc.isClosed, isTrue);
    expect(routeClosed, 1);
  });

  test('mismatched vault does not mark the current backup verified', () async {
    final verifier = _MockVerifyVault();
    final vault = _MockEncryptedVault();
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

  test(
    'maps external failure while storing without announcing creation',
    () async {
      final vault = _MockEncryptedVault();
      when(
        () => createVault.execute(),
      ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
      when(
        () => connectDrive.execute(),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => saveDrive.execute(vault),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
      ).thenAnswer(
        (_) async => const Err(core.ExternalTorProxyUnavailableFailure()),
      );
      final bloc = buildBloc(flow: RecoverBullFlow.secureVault);
      addTearDown(bloc.close);

      bloc.add(
        const OnVaultCreation(
          provider: VaultProvider.googleDrive,
          password: 'pw',
        ),
      );
      await pumpEventQueue();

      expect(bloc.state.failure, isA<ExternalTorProxyUnavailableFailure>());
      expect(bloc.state.vault, isNull);
      verify(
        () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
      ).called(1);
    },
  );

  group('Tor retry concurrency', () {
    test('drops a second retry while the first one is in flight', () async {
      final pending =
          Completer<Result<RecoverBullTorRoute, core.RecoverBullCoreFailure>>();
      when(
        () => ensureRecoverBullTorSession.execute(restartEmbedded: true),
      ).thenAnswer((_) => pending.future);
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

      bloc.add(const OnTorInitialization(restart: true));
      await pumpEventQueue();
      bloc.add(const OnTorInitialization(restart: true));
      await pumpEventQueue();

      verify(
        () => ensureRecoverBullTorSession.execute(restartEmbedded: true),
      ).called(1);

      pending.complete(const Err(core.KeyServerUnavailableFailure()));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<TorNotStartedFailure>());
      await bloc.close();
    });
  });

  group('RecoverBull Tor readiness', () {
    test(
      'keeps a usable route ready during Arti directory refreshes',
      () async {
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        final route = TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
          evidence: TorReadinessEvidence.embeddedBootstrap,
          transport: TorTransport.direct,
        );

        states.add(
          const TorConnecting(
            source: TorSource.embedded,
            progress: 0.76,
            transport: TorTransport.direct,
          ),
        );
        await pumpEventQueue();
        states.add(TorReady(route));
        await pumpEventQueue();
        states.add(
          const TorConnecting(
            source: TorSource.embedded,
            progress: 0.42,
            transport: TorTransport.direct,
          ),
        );
        await pumpEventQueue();

        expect(bloc.state.torConnection, isA<TorReady>());

        states.add(
          const TorUnavailable(
            source: TorSource.embedded,
            failure: TorBootstrapFailure('route lost'),
          ),
        );
        await pumpEventQueue();
        expect(bloc.state.torConnection, isA<TorUnavailable>());

        await states.close();
        await bloc.close();
      },
    );

    test('surfaces a blockage after a previously ready route', () async {
      final states = StreamController<TorConnectionState>();
      when(() => watchTor.execute()).thenAnswer((_) => states.stream);
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      final route = TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.direct,
      );
      states.add(TorReady(route));
      await pumpEventQueue();
      states.add(
        const TorConnecting(
          source: TorSource.embedded,
          progress: 0.42,
          transport: TorTransport.direct,
          diagnostic: TorDiagnostic.offline,
        ),
      );
      await pumpEventQueue();

      expect(
        bloc.state.torConnection,
        const TorConnecting(
          source: TorSource.embedded,
          progress: 0.42,
          transport: TorTransport.direct,
          diagnostic: TorDiagnostic.offline,
        ),
      );

      await states.close();
      await bloc.close();
    });

    test(
      'acquires one flow route when readiness precedes initialization',
      () async {
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        final route = TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
          evidence: TorReadinessEvidence.embeddedBootstrap,
          transport: TorTransport.direct,
        );
        var closeCount = 0;
        final recoverBullRoute = RecoverBullTorRoute(
          route,
          () async => closeCount++,
          HttpClient(),
        );
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(recoverBullRoute));
        when(
          () => checkConnection.execute(route: recoverBullRoute),
        ).thenAnswer((_) async => const Ok(true));

        states.add(TorReady(route));
        await pumpEventQueue();
        bloc.add(const OnTorInitialization());
        await pumpEventQueue();

        expect(bloc.state.keyServerStatus, KeyServerStatus.online);
        verify(() => ensureRecoverBullTorSession.execute()).called(1);
        verify(
          () => checkConnection.execute(route: recoverBullRoute),
        ).called(1);

        await states.close();
        await bloc.close();
        expect(closeCount, 1);
      },
    );

    test('does not dispatch a server check after the bloc closes', () async {
      final pending =
          Completer<Result<RecoverBullTorRoute, core.RecoverBullCoreFailure>>();
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) => pending.future);
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      final route = TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.direct,
      );
      var closeCount = 0;

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();
      final close = bloc.close();
      pending.complete(
        Ok(RecoverBullTorRoute(route, () async => closeCount++, HttpClient())),
      );
      await close;

      verifyNever(() => checkConnection.execute());
      expect(closeCount, 1);
    });

    test('external failure is not replaced by embedded stream state', () async {
      final states = StreamController<TorConnectionState>();
      when(() => watchTor.execute()).thenAnswer((_) => states.stream);
      when(() => ensureRecoverBullTorSession.execute()).thenAnswer(
        (_) async => const Err(core.ExternalTorProxyUnavailableFailure()),
      );
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();
      expect(
        bloc.state.torConnection,
        isA<TorUnavailable>().having(
          (value) => value.source,
          'source',
          TorSource.external,
        ),
      );
      states.add(
        TorReady(
          TorRoute(
            source: TorSource.embedded,
            endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
            evidence: TorReadinessEvidence.embeddedBootstrap,
            transport: TorTransport.direct,
          ),
        ),
      );
      await pumpEventQueue();
      expect(
        bloc.state.torConnection,
        isA<TorUnavailable>().having(
          (value) => value.source,
          'source',
          TorSource.external,
        ),
      );
      verifyNever(() => checkConnection.execute());
      await states.close();
      await bloc.close();
    });

    test(
      'external unavailability checks the retained external route',
      () async {
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        final route = TorRoute(
          source: TorSource.external,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41002),
          evidence: TorReadinessEvidence.externalSocksHandshake,
          transport: TorTransport.direct,
        );
        final recoverBullRoute = RecoverBullTorRoute(
          route,
          () async {},
          HttpClient(),
        );
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(recoverBullRoute));
        when(
          () => checkConnection.execute(route: recoverBullRoute),
        ).thenAnswer((_) async => const Ok(false));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        clearInteractions(checkConnection);
        states.add(
          const TorUnavailable(
            source: TorSource.external,
            failure: TorExternalProxyUnavailableFailure(),
          ),
        );
        await pumpEventQueue();

        verify(
          () => checkConnection.execute(route: recoverBullRoute),
        ).called(3);
        await states.close();
        await bloc.close();
      },
    );
  });
}
