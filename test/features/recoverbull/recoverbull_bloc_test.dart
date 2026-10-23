import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart'
    as core;
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
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
import 'package:bb_mobile/features/recoverbull/domain/usecases/connect_to_key_server_usecase.dart';
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

class _MockEnsureRecoverBullTorSession extends Mock
    implements EnsureRecoverBullTorSessionUsecase {}

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
  late _MockEnsureRecoverBullTorSession ensureRecoverBullTorSession;
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
      ensureRecoverBullTorSession,
    ),
    fetchVaultKeyFromServerUsecase: fetchKey,
    decryptVaultUsecase: decrypt,
    restoreVaultUsecase: restore,
    connectToGoogleDriveUsecase: connectDrive,
    saveToGoogleDriveUsecase: saveDrive,
    ensureRecoverBullTorSessionUsecase: ensureRecoverBullTorSession,
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

        await bloc.close();
      },
    );
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
        final verified = RecoverBullTorRoute(route, () async {});
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(verified));
        when(
          () => checkConnection.execute(route: verified),
        ).thenAnswer((_) async => const Ok(true));

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
      final verified = RecoverBullTorRoute(route, () async {});
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) async => Ok(verified));
      when(
        () => checkConnection.execute(route: verified),
      ).thenAnswer((_) async => const Ok(true));
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
        when(
          () => checkConnection.execute(),
        ).thenAnswer((_) async => const Ok(true));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        final route = TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
          evidence: TorReadinessEvidence.embeddedBootstrap,
          transport: TorTransport.direct,
        );
        final recoverBullRoute = RecoverBullTorRoute(route, () async {});
        when(
          () => ensureRecoverBullTorSession.execute(
            restartEmbedded: any(named: 'restartEmbedded'),
          ),
        ).thenAnswer((_) async => Ok(recoverBullRoute));
        when(
          () => checkConnection.execute(route: recoverBullRoute),
        ).thenAnswer((_) async => const Ok(true));

        states.add(TorReady(route));
        await pumpEventQueue();

        expect(bloc.state.keyServerStatus, KeyServerStatus.online);
        verify(
          () => checkConnection.execute(route: recoverBullRoute),
        ).called(greaterThanOrEqualTo(1));

        await states.close();
        await bloc.close();
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
        Ok(RecoverBullTorRoute(route, () async => closeCount++)),
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
  });
  group('flow-scoped Tor route', () {
    RecoverBullTorRoute routeAt(int port, Future<void> Function() close) =>
        RecoverBullTorRoute(
          TorRoute(
            source: TorSource.embedded,
            endpoint: TorProxyEndpoint(host: '127.0.0.1', port: port),
            evidence: TorReadinessEvidence.embeddedBootstrap,
            transport: TorTransport.direct,
          ),
          close,
        );

    test('retains the checked route until the flow closes', () async {
      var closed = 0;
      final route = routeAt(41001, () async => closed++);
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) async => Ok(route));
      when(
        () => checkConnection.execute(route: route),
      ).thenAnswer((_) async => const Ok(true));
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      addTearDown(bloc.close);

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();

      expect(bloc.state.keyServerStatus, KeyServerStatus.online);
      expect(closed, 0);
      verify(() => ensureRecoverBullTorSession.execute()).called(1);
      verify(() => checkConnection.execute(route: route)).called(1);
      await bloc.close();
      expect(closed, 1);
    });

    test(
      'readiness during initialization does not acquire a competing route',
      () async {
        final pending =
            Completer<
              Result<RecoverBullTorRoute, core.RecoverBullCoreFailure>
            >();
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) => pending.future);
        final route = routeAt(41001, () async {});
        when(
          () => checkConnection.execute(route: route),
        ).thenAnswer((_) async => const Ok(true));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        addTearDown(bloc.close);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        states.add(TorReady(route.route));
        await pumpEventQueue();
        pending.complete(Ok(route));
        await pumpEventQueue();

        verify(() => ensureRecoverBullTorSession.execute()).called(1);
        verify(() => checkConnection.execute(route: route)).called(1);
        await states.close();
        await bloc.close();
      },
    );

    test(
      'a restart releases the old route and checks the replacement',
      () async {
        var firstClosed = 0;
        var secondClosed = 0;
        final first = routeAt(41001, () async => firstClosed++);
        final second = routeAt(41002, () async => secondClosed++);
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(first));
        when(
          () => ensureRecoverBullTorSession.execute(restartEmbedded: true),
        ).thenAnswer((_) async => Ok(second));
        when(
          () => checkConnection.execute(route: first),
        ).thenAnswer((_) async => const Ok(true));
        when(
          () => checkConnection.execute(route: second),
        ).thenAnswer((_) async => const Ok(true));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        addTearDown(bloc.close);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        bloc.add(const OnTorInitialization(restart: true));
        await pumpEventQueue();

        expect(firstClosed, 1);
        expect(secondClosed, 0);
        verify(() => checkConnection.execute(route: second)).called(1);
        await bloc.close();
        expect(secondClosed, 1);
      },
    );

    test('separate flows retain separate isolated routes', () async {
      var firstClosed = 0;
      var secondClosed = 0;
      final first = routeAt(41001, () async => firstClosed++);
      final second = routeAt(41002, () async => secondClosed++);
      var acquisitions = 0;
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) async => Ok(acquisitions++ == 0 ? first : second));
      when(
        () => checkConnection.execute(route: first),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => checkConnection.execute(route: second),
      ).thenAnswer((_) async => const Ok(true));
      final firstFlow = buildBloc(flow: RecoverBullFlow.recoverVault);
      final secondFlow = buildBloc(flow: RecoverBullFlow.recoverVault);
      addTearDown(firstFlow.close);
      addTearDown(secondFlow.close);

      firstFlow.add(const OnTorInitialization());
      secondFlow.add(const OnTorInitialization());
      await pumpEventQueue();

      expect(acquisitions, 2);
      expect(firstClosed, 0);
      expect(secondClosed, 0);
      await firstFlow.close();
      expect(firstClosed, 1);
      expect(secondClosed, 0);
      await secondFlow.close();
      expect(secondClosed, 1);
    });

    test(
      'recovery fetch borrows the route that passed the server check',
      () async {
        final route = routeAt(41001, () async {});
        final vault = _MockEncryptedVault();
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(route));
        when(
          () => checkConnection.execute(route: route),
        ).thenAnswer((_) async => const Ok(true));
        when(
          () => fetchKey.execute(vault: vault, password: 'pw', route: route),
        ).thenAnswer(
          (_) async => const Err(core.KeyServerUnavailableFailure()),
        );
        final bloc = buildBloc(
          flow: RecoverBullFlow.recoverVault,
          preSelectedVault: vault,
        );
        addTearDown(bloc.close);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        bloc.add(const OnVaultPasswordSet(password: 'pw'));
        await pumpEventQueue();

        verify(
          () => fetchKey.execute(vault: vault, password: 'pw', route: route),
        ).called(1);
        verify(() => ensureRecoverBullTorSession.execute()).called(1);
        await bloc.close();
      },
    );

    test('backup preflight and store borrow the checked route', () async {
      final route = routeAt(41001, () async {});
      final vault = _MockEncryptedVault();
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) async => Ok(route));
      when(
        () => checkConnection.execute(route: route),
      ).thenAnswer((_) async => const Ok(true));
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
        () => storeKey.execute(
          password: 'pw',
          vault: vault,
          vaultKey: 'key',
          route: route,
        ),
      ).thenAnswer((_) async => const Ok(null));
      final bloc = buildBloc(flow: RecoverBullFlow.secureVault);
      addTearDown(bloc.close);

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();
      bloc.add(
        const OnVaultCreation(
          provider: VaultProvider.googleDrive,
          password: 'pw',
        ),
      );
      await pumpEventQueue();

      verify(() => checkConnection.execute(route: route)).called(2);
      verify(
        () => storeKey.execute(
          password: 'pw',
          vault: vault,
          vaultKey: 'key',
          route: route,
        ),
      ).called(1);
      verify(() => ensureRecoverBullTorSession.execute()).called(1);
      await bloc.close();
    });

    test(
      'terminal Tor loss retires the route but a directory refresh does not',
      () async {
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        var firstClosed = 0;
        final first = routeAt(41001, () async => firstClosed++);
        final second = routeAt(41002, () async {});
        var acquisitions = 0;
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(acquisitions++ == 0 ? first : second));
        when(
          () => checkConnection.execute(route: first),
        ).thenAnswer((_) async => const Ok(true));
        when(
          () => checkConnection.execute(route: second),
        ).thenAnswer((_) async => const Ok(true));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        addTearDown(bloc.close);
        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        states.add(
          const TorConnecting(
            source: TorSource.embedded,
            progress: .9,
            transport: TorTransport.direct,
          ),
        );
        await pumpEventQueue();
        expect(firstClosed, 0);
        states.add(const TorStopped(TorSource.embedded));
        await pumpEventQueue();
        expect(firstClosed, 1);
        // Readiness alone does not re-check in the background: a failure written here could pop a page the user is on.
        states.add(TorReady(second.route));
        await pumpEventQueue();
        expect(acquisitions, 1);
        expect(bloc.state.failure, isNull);
        verifyNever(() => checkConnection.execute(route: second));
        await states.close();
        await bloc.close();
      },
    );

    test('a new circuit waits for a fetch borrowing the route', () async {
      var closed = 0;
      final route = routeAt(41001, () async => closed++);
      final vault = _MockEncryptedVault();
      final fetching = Completer<Result<String, core.RecoverBullCoreFailure>>();
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) async => Ok(route));
      when(
        () => checkConnection.execute(route: route),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => fetchKey.execute(vault: vault, password: 'pw', route: route),
      ).thenAnswer((_) => fetching.future);
      final bloc = buildBloc(
        flow: RecoverBullFlow.recoverVault,
        preSelectedVault: vault,
      );
      addTearDown(bloc.close);

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();
      bloc.add(const OnVaultPasswordSet(password: 'pw'));
      await pumpEventQueue();
      // The status indicator in the app bar lets the user check mid-fetch.
      when(
        () => checkConnection.execute(route: route),
      ).thenAnswer((_) async => const Ok(false));
      bloc.add(const OnServerCheck());
      await pumpEventQueue();

      expect(bloc.state.failure, isA<KeyServerConnectionFailure>());
      // A failed check keeps the route for Retry.
      expect(closed, 0);
      bloc.add(const OnNewCircuit());
      await pumpEventQueue();
      // The SOCKS listener stays up until the fetch returns.
      expect(closed, 0);
      fetching.complete(const Err(core.KeyServerUnavailableFailure()));
      await pumpEventQueue();
      expect(closed, 1);
    });

    test('a Tor stop waits for a fetch borrowing the route', () async {
      final states = StreamController<TorConnectionState>();
      when(() => watchTor.execute()).thenAnswer((_) => states.stream);
      var closed = 0;
      final route = routeAt(41001, () async => closed++);
      final vault = _MockEncryptedVault();
      final fetching = Completer<Result<String, core.RecoverBullCoreFailure>>();
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) async => Ok(route));
      when(
        () => checkConnection.execute(route: route),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => fetchKey.execute(vault: vault, password: 'pw', route: route),
      ).thenAnswer((_) => fetching.future);
      final bloc = buildBloc(
        flow: RecoverBullFlow.recoverVault,
        preSelectedVault: vault,
      );
      addTearDown(states.close);
      addTearDown(bloc.close);

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();
      bloc.add(const OnVaultPasswordSet(password: 'pw'));
      await pumpEventQueue();
      states.add(const TorStopped(TorSource.embedded));
      await pumpEventQueue();

      // Same policy as a failed check: the listener outlives the call on it.
      expect(bloc.state.torConnection, isA<TorStopped>());
      expect(closed, 0);
      fetching.complete(const Err(core.KeyServerUnavailableFailure()));
      await pumpEventQueue();
      expect(closed, 1);
    });

    test('a diagnostic while connecting keeps the route', () async {
      final states = StreamController<TorConnectionState>();
      when(() => watchTor.execute()).thenAnswer((_) => states.stream);
      var closed = 0;
      final route = routeAt(41001, () async => closed++);
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) async => Ok(route));
      when(
        () => checkConnection.execute(route: route),
      ).thenAnswer((_) async => const Ok(true));
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      addTearDown(states.close);
      addTearDown(bloc.close);
      bloc.add(const OnTorInitialization());
      await pumpEventQueue();
      const blocked = TorConnecting(
        source: TorSource.embedded,
        progress: .42,
        transport: TorTransport.direct,
        diagnostic: TorDiagnostic.offline,
      );
      states.add(blocked);
      await pumpEventQueue();

      expect(bloc.state.torConnection, blocked);
      expect(bloc.state.keyServerStatus, KeyServerStatus.online);
      expect(closed, 0);
    });

    test(
      'an old check cannot replace the result of a restarted route',
      () async {
        final pending = Completer<Result<bool, core.RecoverBullCoreFailure>>();
        final first = routeAt(41001, () async {});
        final second = routeAt(41002, () async {});
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(first));
        when(
          () => ensureRecoverBullTorSession.execute(restartEmbedded: true),
        ).thenAnswer((_) async => Ok(second));
        when(
          () => checkConnection.execute(route: first),
        ).thenAnswer((_) => pending.future);
        when(
          () => checkConnection.execute(route: second),
        ).thenAnswer((_) async => const Ok(true));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        addTearDown(bloc.close);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        bloc.add(const OnTorInitialization(restart: true));
        await pumpEventQueue();
        pending.complete(const Ok(false));
        await pumpEventQueue();

        expect(bloc.state.keyServerStatus, KeyServerStatus.online);
        verify(() => checkConnection.execute(route: second)).called(1);
        await bloc.close();
      },
    );

    test(
      'initial Stopped during bootstrap does not invalidate its acquisition',
      () async {
        final pending =
            Completer<
              Result<RecoverBullTorRoute, core.RecoverBullCoreFailure>
            >();
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) => pending.future);
        var closed = 0;
        final route = routeAt(41001, () async => closed++);
        when(
          () => checkConnection.execute(route: route),
        ).thenAnswer((_) async => const Ok(true));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        addTearDown(bloc.close);
        addTearDown(states.close);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        states.add(const TorStopped(TorSource.embedded));
        await pumpEventQueue();
        pending.complete(Ok(route));
        await pumpEventQueue();

        expect(bloc.state.torConnection, isA<TorReady>());
        expect(bloc.state.keyServerStatus, KeyServerStatus.online);
        expect(closed, 0);
        verify(() => checkConnection.execute(route: route)).called(1);
        await bloc.close();
      },
    );

    test(
      'terminal failure invalidates an acquisition still in flight',
      () async {
        final pending =
            Completer<
              Result<RecoverBullTorRoute, core.RecoverBullCoreFailure>
            >();
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) => pending.future);
        var closed = 0;
        final route = routeAt(41001, () async => closed++);
        when(
          () => checkConnection.execute(route: route),
        ).thenAnswer((_) async => const Ok(true));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        addTearDown(bloc.close);
        addTearDown(states.close);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        const unavailable = TorUnavailable(
          source: TorSource.embedded,
          failure: TorBootstrapFailure('bootstrap failed'),
        );
        states.add(unavailable);
        await pumpEventQueue();
        pending.complete(Ok(route));
        await pumpEventQueue();

        expect(bloc.state.torConnection, unavailable);
        expect(closed, 1);
        verifyNever(() => checkConnection.execute(route: route));
        await bloc.close();
      },
    );

    test(
      'readiness during a failed acquisition resumes with a fresh route',
      () async {
        final pending =
            Completer<
              Result<RecoverBullTorRoute, core.RecoverBullCoreFailure>
            >();
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        var firstClosed = 0;
        var secondClosed = 0;
        final first = routeAt(41001, () async => firstClosed++);
        final second = routeAt(41002, () async => secondClosed++);
        var acquisitions = 0;
        when(() => ensureRecoverBullTorSession.execute()).thenAnswer((_) {
          acquisitions++;
          return acquisitions == 1 ? pending.future : Future.value(Ok(second));
        });
        when(
          () => checkConnection.execute(route: second),
        ).thenAnswer((_) async => const Ok(true));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        addTearDown(states.close);
        addTearDown(bloc.close);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        states.add(
          const TorUnavailable(
            source: TorSource.embedded,
            failure: TorBootstrapFailure('bootstrap failed'),
          ),
        );
        await pumpEventQueue();
        states.add(TorReady(second.route));
        await pumpEventQueue();
        expect(acquisitions, 1);

        pending.complete(Ok(first));
        await pumpEventQueue();

        expect(bloc.state.keyServerStatus, KeyServerStatus.online);
        expect(
          bloc.state.torConnection,
          isA<TorReady>().having((state) => state.route, 'route', second.route),
        );
        expect(acquisitions, 2);
        expect(firstClosed, 1);
        expect(secondClosed, 0);
        verifyNever(() => checkConnection.execute(route: first));
        verify(() => checkConnection.execute(route: second)).called(1);
      },
    );

    for (final pendingPhase in ['preflight', 'picker']) {
      test(
        'disposal during backup $pendingPhase never starts key storage',
        () async {
          final preflight =
              Completer<Result<bool, core.RecoverBullCoreFailure>>();
          final picker = Completer<Result<Null, core.RecoverBullCoreFailure>>();
          var closed = 0;
          final route = routeAt(41001, () async => closed++);
          final vault = _MockEncryptedVault();
          when(() => vault.toFile()).thenReturn('vault');
          when(() => vault.filename).thenReturn('backup.json');
          when(
            () => ensureRecoverBullTorSession.execute(),
          ).thenAnswer((_) async => Ok(route));
          when(
            () => checkConnection.execute(route: route),
          ).thenAnswer((_) async => const Ok(true));
          when(
            () => createVault.execute(),
          ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
          when(
            () => saveFile.execute(content: 'vault', filename: 'backup.json'),
          ).thenAnswer((_) => picker.future);
          when(
            () =>
                storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
          ).thenAnswer((_) async => const Ok(null));
          when(
            () => storeKey.execute(
              password: 'pw',
              vault: vault,
              vaultKey: 'key',
              route: route,
            ),
          ).thenAnswer((_) async => const Ok(null));
          final bloc = buildBloc(flow: RecoverBullFlow.secureVault);
          addTearDown(bloc.close);
          bloc.add(const OnTorInitialization());
          await pumpEventQueue();
          if (pendingPhase == 'preflight') {
            when(
              () => checkConnection.execute(),
            ).thenAnswer((_) => preflight.future);
            when(
              () => checkConnection.execute(route: route),
            ).thenAnswer((_) => preflight.future);
          }
          bloc.add(
            const OnVaultCreation(
              provider: VaultProvider.customLocation,
              password: 'pw',
            ),
          );
          await pumpEventQueue();

          final closing = bloc.close();
          await pumpEventQueue();
          preflight.complete(const Ok(true));
          picker.complete(const Ok(null));
          await closing;

          verifyNever(
            () =>
                storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
          );
          verifyNever(
            () => storeKey.execute(
              password: 'pw',
              vault: vault,
              vaultKey: 'key',
              route: route,
            ),
          );
          verify(() => ensureRecoverBullTorSession.execute()).called(1);
          expect(closed, 1);
          expect(bloc.isClosed, isTrue);
        },
      );
    }

    test(
      'late acquisition cleanup failure does not prevent flow disposal',
      () async {
        final pending =
            Completer<
              Result<RecoverBullTorRoute, core.RecoverBullCoreFailure>
            >();
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) => pending.future);
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        addTearDown(bloc.close);
        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        final closing = bloc.close();
        pending.complete(
          Ok(routeAt(41001, () async => throw Exception('close failed'))),
        );
        await expectLater(closing, completes);
        expect(bloc.isClosed, isTrue);
      },
    );

    test('a Tor drop after the vault is saved still stores the key', () async {
      final states = StreamController<TorConnectionState>();
      when(() => watchTor.execute()).thenAnswer((_) => states.stream);
      var closed = 0;
      final route = routeAt(41001, () async => closed++);
      final vault = _MockEncryptedVault();
      when(() => vault.toFile()).thenReturn('{}');
      when(() => vault.filename).thenReturn('vault.json');
      final saving = Completer<Result<Null, core.RecoverBullCoreFailure>>();
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) async => Ok(route));
      when(
        () => checkConnection.execute(route: route),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => createVault.execute(),
      ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
      when(
        () => saveFile.execute(
          content: any(named: 'content'),
          filename: any(named: 'filename'),
        ),
      ).thenAnswer((_) => saving.future);
      when(
        () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
      ).thenAnswer((_) async => const Ok(null));
      final bloc = buildBloc(flow: RecoverBullFlow.secureVault);
      addTearDown(states.close);
      addTearDown(bloc.close);

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();
      bloc.add(
        const OnVaultCreation(
          provider: VaultProvider.customLocation,
          password: 'pw',
        ),
      );
      await pumpEventQueue();
      // The file picker backgrounds the app, which is when embedded Tor flaps.
      states.add(const TorStopped(TorSource.embedded));
      await pumpEventQueue();
      expect(closed, 1);
      saving.complete(const Ok(null));
      await pumpEventQueue();

      // The file exists, so the key must reach the server through a fresh route rather than be dropped silently.
      expect(bloc.state.failure, isNull);
      expect(bloc.state.vault, vault);
      verify(
        () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
      ).called(1);
    });

    test(
      'reusing the retained route keeps an in-flight check result',
      () async {
        final pending = Completer<Result<bool, core.RecoverBullCoreFailure>>();
        final route = routeAt(41001, () async {});
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(route));
        when(
          () => checkConnection.execute(route: route),
        ).thenAnswer((_) => pending.future);
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        addTearDown(bloc.close);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        pending.complete(const Ok(true));
        await pumpEventQueue();

        expect(bloc.state.keyServerStatus, KeyServerStatus.online);
        verify(() => ensureRecoverBullTorSession.execute()).called(1);
        verify(() => checkConnection.execute(route: route)).called(1);
      },
    );

    test('Retry reuses the session and counts each failed attempt', () async {
      var closed = 0;
      final route = routeAt(41001, () async => closed++);
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) async => Ok(route));
      when(() => checkConnection.execute(route: route)).thenAnswer(
        (_) async => const Err(
          core.KeyServerUnavailableFailure.because(
            core.KeyServerUnreachableCause.circuitTimeout,
          ),
        ),
      );
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      addTearDown(bloc.close);

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();

      expect(bloc.state.keyServerStatus, KeyServerStatus.offline);
      expect(bloc.state.keyServerFailures, 1);
      expect(
        bloc.state.failure,
        isA<KeyServerConnectionFailure>().having(
          (f) => f.cause,
          'cause',
          core.KeyServerUnreachableCause.circuitTimeout,
        ),
      );

      // What the connecting page's Retry dispatches while Tor reads ready.
      bloc.add(const OnServerCheck());
      await pumpEventQueue();

      expect(bloc.state.keyServerFailures, 2);
      verify(() => ensureRecoverBullTorSession.execute()).called(1);
      verify(() => checkConnection.execute(route: route)).called(2);
      expect(closed, 0);
    });

    test(
      'New circuit replaces the session and starts counting again',
      () async {
        var firstClosed = 0;
        final first = routeAt(41001, () async => firstClosed++);
        final second = routeAt(41002, () async {});
        var acquisitions = 0;
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(acquisitions++ == 0 ? first : second));
        when(() => checkConnection.execute(route: first)).thenAnswer(
          (_) async => const Err(core.KeyServerUnavailableFailure()),
        );
        when(
          () => checkConnection.execute(route: second),
        ).thenAnswer((_) async => const Ok(true));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        addTearDown(bloc.close);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        bloc.add(const OnServerCheck());
        await pumpEventQueue();
        expect(bloc.state.keyServerFailures, 2);

        bloc.add(const OnNewCircuit());
        await pumpEventQueue();

        expect(bloc.state.keyServerStatus, KeyServerStatus.online);
        expect(bloc.state.keyServerFailures, 0);
        expect(bloc.state.failure, isNull);
        expect(acquisitions, 2);
        expect(firstClosed, 1);
        verify(() => checkConnection.execute(route: second)).called(1);
      },
    );
  });
}
