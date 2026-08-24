import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart'
    as core;
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/update_latest_encrypted_backup_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/connect_to_key_server_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

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

class _MockEnsureTor extends Mock implements EnsureTorReadyUsecase {}

class _MockRetryTor extends Mock implements RetryTorConnectionUsecase {}

class _MockWalletBloc extends Mock implements WalletBloc {}

class _MockFetchLatestDrive extends Mock
    implements FetchLatestGoogleDriveVaultUsecase {}

class _MockUpdateLatest extends Mock
    implements UpdateLatestEncryptedVaultTestUsecase {}

class _MockWatchTorConnection extends Mock
    implements WatchTorConnectionUsecase {}

class _MockEncryptedVault extends Mock implements EncryptedVault {}

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
  late _MockEnsureTor ensureTor;
  late _MockRetryTor retryTor;
  late _MockWalletBloc walletBloc;
  late _MockFetchLatestDrive fetchLatestDrive;
  late _MockUpdateLatest updateLatest;
  late _MockWatchTorConnection watchTor;

  setUpAll(() {
    registerFallbackValue(_MockEncryptedVault());
  });

  setUp(() {
    pickVault = _MockPickVault();
    saveFile = _MockSaveFile();
    createVault = _MockCreateVault();
    storeKey = _MockStoreKey();
    checkConnection = _MockCheckConnection();
    fetchKey = _MockFetchKey();
    decrypt = _MockDecrypt();
    restore = _MockRestore();
    connectDrive = _MockConnectDrive();
    saveDrive = _MockSaveDrive();
    ensureTor = _MockEnsureTor();
    retryTor = _MockRetryTor();
    walletBloc = _MockWalletBloc();
    fetchLatestDrive = _MockFetchLatestDrive();
    updateLatest = _MockUpdateLatest();
    watchTor = _MockWatchTorConnection();
    when(
      () => watchTor.execute(),
    ).thenAnswer((_) => const Stream<TorConnectionState>.empty());
  });

  // No event is auto-dispatched, so unstubbed mocks stay untouched unless a
  // test drives the matching flow — the Tor subscription above excepted.
  RecoverBullBloc buildBloc({
    required RecoverBullFlow flow,
    EncryptedVault? preSelectedVault,
  }) => RecoverBullBloc(
    flow: flow,
    preSelectedVault: preSelectedVault,
    pickVaultUsecase: pickVault,
    saveFileToSystemUsecase: saveFile,
    createEncryptedVaultUsecase: createVault,
    storeVaultKeyIntoServerUsecase: storeKey,
    checkKeyServerConnectionUsecase: checkConnection,
    connectToKeyServerUsecase: ConnectToKeyServerUsecase(
      checkConnection,
      wait: (_) async {},
    ),
    fetchVaultKeyFromServerUsecase: fetchKey,
    decryptVaultUsecase: decrypt,
    restoreVaultUsecase: restore,
    connectToGoogleDriveUsecase: connectDrive,
    saveToGoogleDriveUsecase: saveDrive,
    ensureTorReadyUsecase: ensureTor,
    retryTorConnectionUsecase: retryTor,
    walletBloc: walletBloc,
    fetchLatestGoogleDriveVaultUsecase: fetchLatestDrive,
    updateLatestEncryptedVaultTestUsecase: updateLatest,
    watchTorConnectionUsecase: watchTor,
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
  });

  group('OnVaultCreation store-key failure mapping', () {
    test(
      'rate-limited storeVaultKey -> VaultRateLimitedFailure (cooldown kept)',
      () async {
        const cooldown = Duration(minutes: 5);
        final vault = _MockEncryptedVault();
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');

        when(
          () => createVault.execute(),
        ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'deadbeef')));
        when(() => checkConnection.execute()).thenAnswer((_) async => true);
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

        await bloc.close();
      },
    );
  });

  group('Tor retry concurrency', () {
    test('drops a second retry while the first one is in flight', () async {
      final pending = Completer<TorConnectionState>();
      when(() => retryTor.execute()).thenAnswer((_) => pending.future);
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

      bloc.add(const OnTorInitialization(restart: true));
      await pumpEventQueue();
      bloc.add(const OnTorInitialization(restart: true));
      await pumpEventQueue();

      verify(() => retryTor.execute()).called(1);

      pending.complete(
        const TorUnavailable(
          source: TorSource.embedded,
          failure: TorBootstrapFailure('bootstrap failed'),
        ),
      );
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

    // The stale-generation arm of _onTorInitialization returns without asking
    // for a server check, so readiness arriving through the watch stream has to
    // trigger one — otherwise the screen sits on "waiting" with no retry.
    test(
      'checks the server when readiness arrives through the stream',
      () async {
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        when(() => checkConnection.execute()).thenAnswer((_) async => true);
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        final route = TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
          evidence: TorReadinessEvidence.embeddedBootstrap,
          transport: TorTransport.direct,
        );

        states.add(TorReady(route));
        await pumpEventQueue();

        expect(bloc.state.keyServerStatus, KeyServerStatus.online);
        verify(() => checkConnection.execute()).called(greaterThanOrEqualTo(1));

        await states.close();
        await bloc.close();
      },
    );

    test('does not dispatch a server check after the bloc closes', () async {
      final pending = Completer<TorConnectionState>();
      when(() => ensureTor.execute()).thenAnswer((_) => pending.future);
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      final route = TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.direct,
      );

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();
      final close = bloc.close();
      pending.complete(TorReady(route));
      await close;

      verifyNever(() => checkConnection.execute());
    });
  });
}
