import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_attempts.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart'
    as core;
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_vault_attempts_usecase.dart';
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
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/connect_to_key_server_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bull_tor/tor.dart' as tor;

part 'bloc.freezed.dart';
part 'event.dart';
part 'state.dart';

class RecoverBullBloc extends Bloc<RecoverBullEvent, RecoverBullState> {
  final PickVaultUsecase _pickVaultUsecase;
  final SaveFileToSystemUsecase _saveFileToSystemUsecase;
  final ConnectToGoogleDriveUsecase _connectToGoogleDriveUsecase;
  final SaveVaultToGoogleDriveUsecase _saveToGoogleDriveUsecase;
  final CreateEncryptedVaultUsecase _createEncryptedVaultUsecase;
  final StoreVaultKeyIntoServerUsecase _storeVaultKeyIntoServerUsecase;

  /// Single-shot: the pre-flight check before storing a vault key, where the
  /// user is already committed and a retry budget would only delay the error.
  final CheckServerConnectionUsecase _checkKeyServerConnectionUsecase;

  /// Retrying: the connecting screen, where a cold onion lookup is expected to
  /// need more than one try.
  final ConnectToKeyServerUsecase _connectToKeyServerUsecase;
  final FetchVaultKeyFromServerUsecase _fetchVaultKeyFromServerUsecase;
  final CheckVaultAttemptsUsecase _checkVaultAttemptsUsecase;
  final DecryptVaultUsecase _decryptVaultUsecase;
  final RestoreVaultUsecase _restoreVaultUsecase;
  final EnsureRecoverBullTorSessionUsecase _ensureRecoverBullTorSessionUsecase;
  final WalletBloc _walletBloc;
  final FetchLatestGoogleDriveVaultUsecase _fetchLatestGoogleDriveVaultUsecase;
  final UpdateLatestEncryptedVaultTestUsecase
  _updateLatestEncryptedVaultTestUsecase;
  final tor.WatchTorConnectionUsecase _watchTorConnectionUsecase;

  StreamSubscription<tor.TorConnectionState>? _torSubscription;
  Future<Result<RecoverBullTorRoute, core.RecoverBullCoreFailure>>?
  _pendingRoutePreparation;
  RecoverBullTorRoute? _flowRoute;
  int _routeBorrowers = 0;
  final List<RecoverBullTorRoute> _routesToCloseAfterBorrow = [];
  tor.TorSource? _pendingRouteFailureSource;
  int _routeGeneration = 0;
  bool _closingBloc = false;

  RecoverBullBloc({
    required RecoverBullFlow flow,
    EncryptedVault? preSelectedVault,
    required this._pickVaultUsecase,
    required this._saveFileToSystemUsecase,
    required this._createEncryptedVaultUsecase,
    required this._storeVaultKeyIntoServerUsecase,
    required this._checkKeyServerConnectionUsecase,
    required this._connectToKeyServerUsecase,
    required this._fetchVaultKeyFromServerUsecase,
    required this._checkVaultAttemptsUsecase,
    required this._decryptVaultUsecase,
    required this._restoreVaultUsecase,
    required this._connectToGoogleDriveUsecase,
    required this._saveToGoogleDriveUsecase,
    required this._ensureRecoverBullTorSessionUsecase,
    required this._walletBloc,
    required this._fetchLatestGoogleDriveVaultUsecase,
    required this._updateLatestEncryptedVaultTestUsecase,
    required this._watchTorConnectionUsecase,
  }) : super(RecoverBullState(flow: flow, vault: preSelectedVault)) {
    on<OnVaultProviderSelection>(_onVaultProviderSelection);
    on<OnVaultSelection>(_onVaultSelection);
    on<OnVaultPasswordSet>(_onVaultPasswordSet);
    on<OnVaultCreation>(_onVaultCreation);
    on<OnVaultDecryption>(_onVaultDecryption);
    on<OnServerCheck>(_onServerCheck, transformer: droppable());
    on<OnTorInitialization>(_onTorInitialization, transformer: droppable());
    on<OnClearError>(_onClearError);
    on<_OnTorConnectionChanged>(
      _onTorConnectionChanged,
      transformer: sequential(),
    );
    // A newly selected vault replaces an in-flight check of the previous one.
    on<OnVaultAttemptsCheck>(_onVaultAttemptsCheck, transformer: restartable());

    // Tor readiness is pushed, so follow it for as long as this flow is open.
    // Taking a single snapshot in `_onServerCheck` reported whatever the status
    // happened to be at T=0 — during a cold start that is "not ready", which
    // the UI rendered as a Tor failure while bootstrap was still running, and
    // it never updated once Tor came up.
    _torSubscription = _watchTorConnectionUsecase.execute().listen(
      (state) => add(_OnTorConnectionChanged(state)),
    );
  }

  @override
  Future<void> close() async {
    _closingBloc = true;
    _routeGeneration++;
    await _torSubscription?.cancel();
    final pending = _pendingRoutePreparation;
    if (pending != null) {
      if (await pending case Ok(:final value)) await _closeRoute(value);
    }
    final route = _flowRoute;
    _flowRoute = null;
    if (route != null) await _closeRoute(route);
    return super.close();
  }

  Future<void> _closeRoute(RecoverBullTorRoute route) async {
    try {
      await route.close();
    } catch (error, stackTrace) {
      log.warning(
        'closing RecoverBull route failed',
        error: error,
        trace: stackTrace,
      );
    }
  }

  Future<void> _onTorConnectionChanged(
    _OnTorConnectionChanged event,
    Emitter<RecoverBullState> emit,
  ) async {
    // Arti's directory fraction is not monotonic after traffic becomes usable:
    // a background refresh can report Connecting again while the established
    // SOCKS route remains valid. RecoverBull only needs that route, so keep its
    // local readiness latched until Tor reports an actual blockage or a
    // terminal state. A diagnostic means this is not a benign refresh.
    final next = event.state;
    if (state.torConnection case tor.TorReady(
      :final route,
    ) when route.source == tor.TorSource.external) {
      return;
    }
    if (state.torConnection case tor.TorConnecting(
      :final source,
    ) when source == tor.TorSource.external) {
      return;
    }
    if (state.torConnection case tor.TorUnavailable(
      :final source,
    ) when source == tor.TorSource.external) {
      return;
    }
    if (state.torConnection is tor.TorReady &&
        next is tor.TorConnecting &&
        next.diagnostic == null) {
      return;
    }
    if (next case tor.TorUnavailable(
      :final source,
    ) when _pendingRoutePreparation != null) {
      _pendingRouteFailureSource = source;
    }
    // Only a terminal state retires the route. A diagnostic on Connecting is best-effort and often a directory refresh over a live SOCKS route, which the connecting page already rides out with a grace period.
    // The generation and the key-server status are left alone: a check in flight reports its own failure, and recovery waits for the next user action. A background re-check writing `failure` here would pop the fetch page mid-fetch.
    final route = _flowRoute;
    final invalidated =
        next is tor.TorStopped ||
        next is tor.TorUninitialized ||
        next is tor.TorUnavailable;
    if (route != null && invalidated) {
      await _retireFlowRoute(route);
      if (isClosed || _closingBloc) return;
    }
    emit(state.copyWith(torConnection: next));

    if (next is tor.TorReady &&
        state.keyServerStatus == KeyServerStatus.unknown &&
        _pendingRoutePreparation == null) {
      // Readiness does not own an isolated route. Let initialization acquire it exactly once before checking the server.
      add(
        _flowRoute == null
            ? const OnTorInitialization()
            : const OnServerCheck(),
      );
    }
  }

  Future<void> _onTorInitialization(
    OnTorInitialization event,
    Emitter<RecoverBullState> emit,
  ) async {
    final retained = _flowRoute;
    if (!event.restart && retained != null) {
      // The route is kept, so the generation is not bumped: work in flight on it stays valid.
      emit(
        state.copyWith(
          failure: null,
          keyServerStatus: KeyServerStatus.unknown,
          torConnection: tor.TorReady(retained.route),
        ),
      );
      add(const OnServerCheck());
      return;
    }
    final generation = ++_routeGeneration;
    emit(
      state.copyWith(failure: null, keyServerStatus: KeyServerStatus.unknown),
    );
    if (retained != null) await _retireFlowRoute(retained);
    if (isClosed || _closingBloc) return;
    var restartEmbedded = event.restart;
    while (!isClosed && !_closingBloc && generation == _routeGeneration) {
      _pendingRouteFailureSource = null;
      final preparation = _ensureRecoverBullTorSessionUsecase.execute(
        restartEmbedded: restartEmbedded,
      );
      restartEmbedded = false;
      _pendingRoutePreparation = preparation;
      final result = await preparation;
      final failedSource = _pendingRouteFailureSource;
      _pendingRouteFailureSource = null;
      if (identical(_pendingRoutePreparation, preparation)) {
        _pendingRoutePreparation = null;
      }
      if (isClosed || _closingBloc || generation != _routeGeneration) {
        if (result case Ok(:final value)) await _closeRoute(value);
        return;
      }
      // A real failure observed during acquisition invalidates that source's late route. An initial Stopped event is normal bootstrap setup.
      if (result case Ok(:final value) when value.source == failedSource) {
        await _closeRoute(value);
        // Ready may have arrived while acquisition was pending. Retry here because a new initialization event would be dropped by this handler.
        if (state.torConnection is tor.TorReady) continue;
        return;
      }
      switch (result) {
        case Ok(:final value):
          _flowRoute = value;
          emit(state.copyWith(torConnection: tor.TorReady(value.route)));
          add(const OnServerCheck());
        case Err(:final failure):
          final torFailure = failure is core.ExternalTorProxyUnavailableFailure
              ? tor.TorExternalProxyUnavailableFailure(failure.logMessage)
              : tor.TorBootstrapFailure(failure.logMessage);
          emit(
            state.copyWith(
              torConnection: tor.TorUnavailable(
                source: failure is core.ExternalTorProxyUnavailableFailure
                    ? tor.TorSource.external
                    : tor.TorSource.embedded,
                failure: torFailure,
              ),
              failure: _torFailure(failure),
              keyServerStatus: KeyServerStatus.offline,
            ),
          );
      }
      return;
    }
  }

  Future<void> _onServerCheck(
    OnServerCheck event,
    Emitter<RecoverBullState> emit,
  ) async {
    final route = _flowRoute;
    if (route == null) {
      // Nothing to check through yet. Initialization acquires the flow's route and chains back here.
      add(const OnTorInitialization());
      return;
    }
    final generation = _routeGeneration;
    try {
      // `torStatus` is not emitted here: it is driven by the subscription set
      // up in the constructor. Emitting a snapshot at this point is what made a
      // healthy cold start look like a Tor failure.
      const retries = ConnectToKeyServerUsecase.maxAttempts;
      emit(
        state.copyWith(
          failure: null,
          keyServerStatus: KeyServerStatus.connecting,
          keyServerAttempt: 0,
          keyServerAttempts: retries,
        ),
      );

      final result = await _connectToKeyServerUsecase.execute(
        route: route,
        // Published before the call, so the screen shows which attempt is
        // actually in flight rather than which one already failed. Guarded:
        // the backoff outlives the screen when the user navigates away.
        onAttempt: (attempt) {
          if (isClosed || _closingBloc || generation != _routeGeneration) {
            return;
          }
          emit(state.copyWith(keyServerAttempt: attempt));
        },
      );
      if (isClosed || _closingBloc || generation != _routeGeneration) return;

      switch (result) {
        case Err(:final failure):
          await _releaseFlowRoute(route);
          if (isClosed || _closingBloc) return;
          emit(
            state.copyWith(
              failure: _fetchKeyFailure(failure),
              keyServerStatus: KeyServerStatus.offline,
            ),
          );
        case Ok(value: false):
          log.severe(
            error: 'Recoverbull server is not ready after $retries retries',
            trace: StackTrace.current,
          );
          await _releaseFlowRoute(route);
          if (isClosed || _closingBloc) return;
          emit(
            state.copyWith(
              failure: const KeyServerConnectionFailure(),
              keyServerStatus: KeyServerStatus.offline,
            ),
          );
        case Ok(value: true):
          log.fine(
            'Recoverbull server ready after ${state.keyServerAttempt} attempts',
          );
          // Tor's status is not forced here. It used to be set to `online` on
          // this path, which asserted Tor's health from the key server's reply;
          // the readiness stream is the only thing that knows, and the screen
          // latches it.
          emit(state.copyWith(keyServerStatus: KeyServerStatus.online));
          // On the verified route, before any PIN is typed, so the count is
          // not the user's own from this screen.
          if (state.vault != null &&
              state.flow != RecoverBullFlow.secureVault &&
              state.vaultAttempts == null) {
            add(const OnVaultAttemptsCheck());
          }
      }
    } catch (e) {
      if (isClosed || _closingBloc || generation != _routeGeneration) return;
      log.severe(error: e, trace: StackTrace.current);
      await _releaseFlowRoute(route);
      if (isClosed || _closingBloc) return;
      emit(
        state.copyWith(
          failure: RecoverBullUnexpectedFailure(e.toString()),
          keyServerStatus: KeyServerStatus.offline,
        ),
      );
    } finally {
      // A replacement's check may have been dropped while this old check was in flight. Check the current route before leaving the handler.
      if (!isClosed &&
          !_closingBloc &&
          generation != _routeGeneration &&
          _flowRoute != null) {
        await _onServerCheck(event, emit);
      }
    }
  }

  // A failed check cannot tell a dead SOCKS session from a server outage. Dropping the route makes the next check acquire a fresh one instead of retrying through a session that may be gone.
  Future<void> _releaseFlowRoute(RecoverBullTorRoute route) async {
    if (!identical(_flowRoute, route)) return;
    await _retireFlowRoute(route);
  }

  // The one way a route leaves the flow: nothing borrows it from now on, and its SOCKS listener closes once the last borrower returns, since closing it under a fetch or store would fail that call.
  Future<void> _retireFlowRoute(RecoverBullTorRoute route) async {
    if (identical(_flowRoute, route)) _flowRoute = null;
    if (_routeBorrowers > 0) {
      _routesToCloseAfterBorrow.add(route);
      return;
    }
    await _closeRoute(route);
  }

  // Runs a key-server call on the retained route, if any.
  Future<T> _borrowRoute<T>(
    Future<T> Function(RecoverBullTorRoute? route) call,
  ) async {
    _routeBorrowers++;
    try {
      return await call(_flowRoute);
    } finally {
      _routeBorrowers--;
      if (_routeBorrowers == 0) {
        final pending = [..._routesToCloseAfterBorrow];
        _routesToCloseAfterBorrow.clear();
        for (final route in pending) {
          await _closeRoute(route);
        }
      }
    }
  }

  Future<void> _onVaultPasswordSet(
    OnVaultPasswordSet event,
    Emitter<RecoverBullState> emit,
  ) async {
    switch (state.flow) {
      case RecoverBullFlow.secureVault:
        emit(state.copyWith(vaultPassword: event.password));
      default:
        if (state.vault == null) {
          emit(state.copyWith(failure: const VaultNotSetFailure()));
          return;
        }
        emit(state.copyWith(vaultPassword: event.password));

        await _onFetchVaultKey(
          OnVaultFetchKey(vault: state.vault!, password: event.password),
          emit,
        );
    }
  }

  Future<void> _onVaultProviderSelection(
    OnVaultProviderSelection event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));

      switch (state.flow) {
        case RecoverBullFlow.secureVault:
          if (state.vaultPassword == null) {
            emit(state.copyWith(failure: const PasswordNotSetFailure()));
            return;
          }

          await _onVaultCreation(
            OnVaultCreation(
              provider: event.provider,
              password: state.vaultPassword!,
            ),
            emit,
          );
          emit(state.copyWith(vaultProvider: event.provider));
        case RecoverBullFlow.recoverVault:
          emit(state.copyWith(vaultProvider: event.provider));
          add(OnVaultSelection(provider: event.provider));
        case RecoverBullFlow.testVault:
          emit(state.copyWith(vaultProvider: event.provider));
          add(OnVaultSelection(provider: event.provider));
        case RecoverBullFlow.viewVaultKey:
          emit(state.copyWith(vaultProvider: event.provider));
          add(OnVaultSelection(provider: event.provider));
        case RecoverBullFlow.settings:
          throw UnimplementedError();
      }
      log.fine('Vault provider ${event.provider.name} selected');
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      emit(state.copyWith(failure: RecoverBullUnexpectedFailure(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onVaultSelection(
    OnVaultSelection event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));

      switch (event.provider) {
        case VaultProvider.googleDrive:
          final connected = await _connectToGoogleDriveUsecase.execute();
          if (connected case Err(:final failure)) {
            emit(state.copyWith(failure: _selectFailure(failure)));
            return;
          }
          switch (await _fetchLatestGoogleDriveVaultUsecase.execute()) {
            case Ok(:final value):
              emit(state.copyWith(vault: value, vaultAttempts: null));
            case Err(:final failure):
              emit(state.copyWith(failure: _selectFailure(failure)));
          }
        case VaultProvider.customLocation:
          switch (await _pickVaultUsecase.execute()) {
            case Ok(:final value):
              emit(state.copyWith(vault: value, vaultAttempts: null));
            case Err(:final failure):
              emit(state.copyWith(failure: _selectFailure(failure)));
          }
        case VaultProvider.iCloud:
          log.warning('iCloud, not supported yet');
      }
      log.fine('Vault selected');
      // Before any PIN is typed, so the count is not the user's own from this
      // screen. Only on a verified route: while the server is not online, the
      // server check dispatches it once it is, instead of a second Tor session
      // bootstrapping next to the flow's route.
      if (state.vault != null &&
          state.flow != RecoverBullFlow.secureVault &&
          state.keyServerStatus == KeyServerStatus.online) {
        add(const OnVaultAttemptsCheck());
      }
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onVaultCreation(
    OnVaultCreation event,
    Emitter<RecoverBullState> emit,
  ) async {
    // Not tied to the route generation: the vault may already be saved when Tor flaps, and the key must still reach the server through whatever route is current.
    bool isCurrent() => !isClosed && !_closingBloc && !emit.isDone;
    if (!isCurrent()) return;
    try {
      emit(state.copyWith(isLoading: true));

      final EncryptedVault vault;
      final String vaultKey;
      final created = await _createEncryptedVaultUsecase.execute();
      if (!isCurrent()) return;
      switch (created) {
        case Ok(:final value):
          vault = value.vault;
          vaultKey = value.vaultKey;
        case Err():
          emit(state.copyWith(failure: const VaultCreationFailure()));
          return;
      }

      final checked = await _borrowRoute(
        (route) => _checkKeyServerConnectionUsecase.execute(route: route),
      );
      if (!isCurrent()) return;
      switch (checked) {
        case Ok(value: true):
          break;
        case Ok():
          emit(state.copyWith(failure: const KeyServerConnectionFailure()));
          return;
        case Err(:final failure):
          emit(state.copyWith(failure: _storeKeyFailure(failure)));
          return;
      }

      switch (event.provider) {
        case VaultProvider.customLocation:
          final saved = await _saveFileToSystemUsecase.execute(
            content: vault.toFile(),
            filename: vault.filename,
          );
          if (!isCurrent()) return;
          if (saved case Err()) {
            emit(state.copyWith(failure: const VaultCreationFailure()));
            return;
          }
        case VaultProvider.googleDrive:
          final connected = await _connectToGoogleDriveUsecase.execute();
          if (!isCurrent()) return;
          if (connected case Err()) {
            emit(state.copyWith(failure: const VaultCreationFailure()));
            return;
          }
          final stored = await _saveToGoogleDriveUsecase.execute(vault);
          if (!isCurrent()) return;
          if (stored case Err()) {
            emit(state.copyWith(failure: const VaultCreationFailure()));
            return;
          }
        case VaultProvider.iCloud:
          log.warning('iCloud, not supported yet');
      }

      if (!isCurrent()) return;
      final keyStored = await _borrowRoute(
        (route) => _storeVaultKeyIntoServerUsecase.execute(
          route: route,
          password: event.password,
          vault: vault,
          vaultKey: vaultKey,
        ),
      );
      if (!isCurrent()) return;
      if (keyStored case Err(:final failure)) {
        // Keep the typed key-server detail (rate-limit cooldown, invalid
        // credentials) instead of collapsing it to the generic creation error.
        emit(state.copyWith(failure: _storeKeyFailure(failure)));
        return;
      }

      emit(state.copyWith(vault: vault, vaultProvider: event.provider));
      log.fine('Vault created and key stored in server');
    } finally {
      if (!isClosed && !_closingBloc && !emit.isDone) {
        emit(state.copyWith(isLoading: false));
      }
    }
  }

  Future<void> _onFetchVaultKey(
    OnVaultFetchKey event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      if (state.flow == RecoverBullFlow.secureVault) return;

      emit(state.copyWith(isLoading: true, vaultKey: null));

      final fetched = await _borrowRoute(
        (route) => _fetchVaultKeyFromServerUsecase.execute(
          route: route,
          vault: event.vault,
          password: event.password,
        ),
      );
      switch (fetched) {
        case Ok(:final value):
          emit(state.copyWith(vaultKey: value));
          log.fine('Vault key fetched from server');
          await _onVaultDecryption(OnVaultDecryption(vaultKey: value), emit);
        case Err(:final failure):
          emit(state.copyWith(failure: _fetchKeyFailure(failure)));
      }
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onVaultDecryption(
    OnVaultDecryption event,
    Emitter<RecoverBullState> emit,
  ) async {
    if (state.vault == null) {
      emit(state.copyWith(failure: const VaultNotSetFailure()));
      return;
    }

    final vaultKey = event.vaultKey;
    final vault = state.vault!;

    try {
      emit(state.copyWith(isLoading: true));

      final DecryptedVault decryptedVault;
      switch (_decryptVaultUsecase.execute(vault: vault, vaultKey: vaultKey)) {
        case Ok(:final value):
          decryptedVault = value;
        case Err():
          emit(state.copyWith(failure: const VaultDecryptionFailure()));
          return;
      }

      switch (state.flow) {
        case RecoverBullFlow.viewVaultKey || RecoverBullFlow.testVault:
          final updated = await _updateLatestEncryptedVaultTestUsecase.execute(
            decryptedVault: decryptedVault,
          );
          if (updated case Err()) {
            emit(state.copyWith(failure: const VaultDecryptionFailure()));
            return;
          }
          emit(state.copyWith(decryptedVault: decryptedVault));
        case RecoverBullFlow.recoverVault:
          emit(state.copyWith(decryptedVault: decryptedVault));
          final updated = await _updateLatestEncryptedVaultTestUsecase.execute(
            decryptedVault: decryptedVault,
          );
          if (updated case Err()) {
            emit(state.copyWith(failure: const VaultDecryptionFailure()));
            return;
          }
          await _restoreAndStart(decryptedVault, emit);
          return;
        case RecoverBullFlow.secureVault:
          throw UnimplementedError();
        case RecoverBullFlow.settings:
          throw UnimplementedError();
      }

      emit(state.copyWith(vaultKey: vaultKey));
      log.fine('Vault decrypted');
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      emit(state.copyWith(failure: const VaultDecryptionFailure()));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  // Persists the recovered wallets, kicks off the real WalletBloc sync, and
  // marks the flow finished so `FetchVaultKeyPage` can navigate straight to
  // the wallet home. Replaces the deprecated dry-scan preview screen, which
  // showed a balance/tx preview gated behind a manual "Continue" button.
  Future<void> _restoreAndStart(
    DecryptedVault decryptedVault,
    Emitter<RecoverBullState> emit,
  ) async {
    switch (await _restoreVaultUsecase.execute(
      decryptedVault: decryptedVault,
    )) {
      case Ok():
        _walletBloc.add(const WalletStarted());
        log.fine('Vault recovered');
        emit(state.copyWith(isFlowFinished: true, isLoading: false));
      case Err():
        emit(
          state.copyWith(
            failure: const VaultRecoveryFailure(),
            isLoading: false,
          ),
        );
    }
  }

  Future<void> _onVaultAttemptsCheck(
    OnVaultAttemptsCheck event,
    Emitter<RecoverBullState> emit,
  ) async {
    final vault = state.vault;
    if (vault == null) return;
    final checked = await _borrowRoute(
      (route) => _checkVaultAttemptsUsecase.execute(vault: vault, route: route),
    );
    switch (checked) {
      case Ok(:final value):
        // The user may have picked another vault while the snapshot was read;
        // this count belongs to the vault it was read for.
        if (isClosed || _closingBloc || !identical(state.vault, vault)) return;
        emit(state.copyWith(vaultAttempts: value));
      case Err(:final failure):
        // Advisory: an unreadable snapshot must never block a recovery.
        log.warning('vault attempts unknown: ${failure.runtimeType}');
    }
  }

  Future<void> _onClearError(
    OnClearError event,
    Emitter<RecoverBullState> emit,
  ) async {
    emit(state.copyWith(failure: null));
  }

  // Maps a core failure surfaced while selecting/fetching a vault.
  RecoverBullFailure _selectFailure(core.RecoverBullCoreFailure failure) =>
      switch (failure) {
        core.InvalidVaultFileFailure() => const InvalidVaultFileFormatFailure(),
        _ => const SelectVaultFailure(),
      };

  // Maps a core failure surfaced while fetching the vault key from the server.
  RecoverBullFailure _fetchKeyFailure(core.RecoverBullCoreFailure failure) =>
      switch (failure) {
        core.KeyServerInvalidCredentialsFailure() =>
          const InvalidVaultCredentialsFailure(),
        core.KeyServerRejectedFailure() =>
          const InvalidVaultCredentialsFailure(),
        core.KeyServerRateLimitedFailure(:final retryIn) =>
          VaultRateLimitedFailure(retryIn: retryIn ?? Duration.zero),
        core.KeyServerUnavailableFailure() => const VaultKeyFetchFailure(),
        core.ExternalTorProxyUnavailableFailure() =>
          const ExternalTorProxyUnavailableFailure(),
        _ => RecoverBullUnexpectedFailure(failure.logMessage),
      };

  // Maps a core failure surfaced while storing the vault key during creation.
  // Mirrors [_fetchKeyFailure] for the shared key-server cases (so a 429
  // cooldown or invalid credentials still reach the user) but falls back to the
  // creation-specific error instead of the generic unexpected one.
  RecoverBullFailure _storeKeyFailure(
    core.RecoverBullCoreFailure failure,
  ) => switch (failure) {
    core.KeyServerInvalidCredentialsFailure() =>
      const InvalidVaultCredentialsFailure(),
    core.KeyServerRejectedFailure() => const InvalidVaultCredentialsFailure(),
    core.KeyServerRateLimitedFailure(:final retryIn) => VaultRateLimitedFailure(
      retryIn: retryIn ?? Duration.zero,
    ),
    core.KeyServerUnavailableFailure() => const KeyServerConnectionFailure(),
    core.ExternalTorProxyUnavailableFailure() =>
      const ExternalTorProxyUnavailableFailure(),
    _ => const VaultCreationFailure(),
  };

  RecoverBullFailure _torFailure(core.RecoverBullCoreFailure failure) =>
      switch (failure) {
        core.ExternalTorProxyUnavailableFailure() =>
          const ExternalTorProxyUnavailableFailure(),
        _ => const TorNotStartedFailure(),
      };
}
