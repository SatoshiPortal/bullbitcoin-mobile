import 'dart:async';

import 'package:bull_recoverbull/src/domain/entity/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entity/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entity/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart' as core;
import 'package:bull_recoverbull/src/domain/ports.dart';
import 'package:bull_recoverbull/src/domain/usecases/check_server_connection_usecase.dart';
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
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/verify_decrypted_vault_usecase.dart';
import 'package:bull_recoverbull/src/support/logger.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_recoverbull/src/domain/usecases/connect_to_key_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/presentation_failure.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
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
  final RegisterMonitoredBackupUsecase? _registerMonitoredBackupUsecase;

  /// Single-shot: the pre-flight check before storing a vault key, where the
  /// user is already committed and a retry budget would only delay the error.
  final CheckServerConnectionUsecase _checkKeyServerConnectionUsecase;

  /// Retrying: the connecting screen, where a cold onion lookup is expected to
  /// need more than one try.
  final ConnectToKeyServerUsecase _connectToKeyServerUsecase;
  final FetchVaultKeyFromServerUsecase _fetchVaultKeyFromServerUsecase;
  final DecryptVaultUsecase _decryptVaultUsecase;
  final RestoreVaultUsecase _restoreVaultUsecase;
  final EnsureRecoverBullTorSessionUsecase _ensureRecoverBullTorSessionUsecase;
  final Future<void> Function()? onWalletUpdated;
  final FetchLatestGoogleDriveVaultUsecase _fetchLatestGoogleDriveVaultUsecase;
  final tor.WatchTorConnectionUsecase _watchTorConnectionUsecase;
  final RecoverBullLifecyclePort? lifecycle;
  final VerifyDecryptedVaultUsecase verifyDecryptedVaultUsecase;

  StreamSubscription<tor.TorConnectionState>? _torSubscription;
  Future<Result<RecoverBullTorRoute, core.RecoverBullCoreFailure>>?
  _pendingRoutePreparation;
  bool _closingBloc = false;
  RecoverBullTorRoute? _route;
  int _routeGeneration = 0;
  EncryptedVault? _pendingProviderVault;

  RecoverBullBloc({
    required RecoverBullFlow flow,
    EncryptedVault? preSelectedVault,
    required this._pickVaultUsecase,
    required this._saveFileToSystemUsecase,
    required this._createEncryptedVaultUsecase,
    required this._storeVaultKeyIntoServerUsecase,
    this._registerMonitoredBackupUsecase,
    required this._checkKeyServerConnectionUsecase,
    required this._connectToKeyServerUsecase,
    required this._fetchVaultKeyFromServerUsecase,
    required this._decryptVaultUsecase,
    required this._restoreVaultUsecase,
    required this._connectToGoogleDriveUsecase,
    required this._saveToGoogleDriveUsecase,
    required this._ensureRecoverBullTorSessionUsecase,
    this.onWalletUpdated,
    required this._fetchLatestGoogleDriveVaultUsecase,
    required this._watchTorConnectionUsecase,
    this.lifecycle,
    required this.verifyDecryptedVaultUsecase,
  }) : super(RecoverBullState(flow: flow, vault: preSelectedVault)) {
    on<OnVaultProviderSelection>(
      _onVaultProviderSelection,
      transformer: droppable(),
    );
    on<OnVaultSelection>(_onVaultSelection);
    on<OnVaultPasswordSet>(_onVaultPasswordSet, transformer: droppable());
    on<OnVaultCreation>(_onVaultCreation, transformer: droppable());
    on<OnVaultDecryption>(_onVaultDecryption, transformer: droppable());
    on<OnServerCheck>(_onServerCheck, transformer: droppable());
    on<OnTorInitialization>(_onTorInitialization, transformer: droppable());
    on<OnClearError>(_onClearError);
    on<_OnTorConnectionChanged>(_onTorConnectionChanged);

    // Tor readiness is pushed, so follow it for as long as this flow is open.
    // Taking a single snapshot in `_onServerCheck` reported whatever the status
    // happened to be at T=0 — during a cold start that is "not ready", which
    // the UI rendered as a Tor failure while bootstrap was still running, and
    // it never updated once Tor came up.
    _torSubscription = _watchTorConnectionUsecase.execute().listen(
      (state) => add(_OnTorConnectionChanged(state)),
    );
  }

  /// Only the encrypted vault is retained while a provider save is retried.
  bool get hasPendingProviderSave => _pendingProviderVault != null;

  @override
  Future<void> close() async {
    _closingBloc = true;
    _pendingProviderVault = null;
    await _torSubscription?.cancel();
    final pending = _pendingRoutePreparation;
    if (pending != null) {
      final result = await pending;
      if (result case Ok(:final value)) {
        await value.closeQuietly();
      }
    }
    try {
      await _route?.close();
    } catch (error, stackTrace) {
      log.warning(
        'closing RecoverBull route failed',
        error: error,
        trace: stackTrace,
      );
    }
    return super.close();
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
    final nextIsExternal = switch (next) {
      tor.TorReady(:final route) => route.source == tor.TorSource.external,
      tor.TorConnecting(:final source) => source == tor.TorSource.external,
      tor.TorUnavailable(:final source) => source == tor.TorSource.external,
      tor.TorUninitialized() || tor.TorStopped() => false,
    };
    if (state.torConnection case tor.TorReady(
      :final route,
    ) when route.source == tor.TorSource.external && !nextIsExternal) {
      return;
    }
    if (state.torConnection case tor.TorConnecting(
      :final source,
    ) when source == tor.TorSource.external && !nextIsExternal) {
      return;
    }
    if (state.torConnection case tor.TorUnavailable(
      :final source,
    ) when source == tor.TorSource.external && !nextIsExternal) {
      return;
    }
    if (state.torConnection is tor.TorReady &&
        next is tor.TorConnecting &&
        next.diagnostic == null) {
      return;
    }
    emit(state.copyWith(torConnection: next));

    // An external proxy has no embedded lifecycle to restart. Let the real
    // server check observe whether the retained external route is still usable;
    // never manufacture recovery from an embedded readiness event.
    if (next is tor.TorUnavailable && nextIsExternal && _route != null) {
      add(const OnServerCheck());
    }

    // The global readiness stream can emit before the flow's initialization
    // event. It proves embedded Tor is ready, but it does not own the isolated
    // route that this flow must reuse. Wait for `_onTorInitialization` to
    // acquire that route instead of starting a competing server check with a
    // second short-lived route.
    if (next is tor.TorReady &&
        state.keyServerStatus == KeyServerStatus.unknown &&
        _route != null) {
      add(const OnServerCheck());
    }
  }

  Future<void> _onTorInitialization(
    OnTorInitialization event,
    Emitter<RecoverBullState> emit,
  ) async {
    emit(
      state.copyWith(failure: null, keyServerStatus: KeyServerStatus.unknown),
    );
    if (!event.restart && _route != null) {
      emit(state.copyWith(torConnection: tor.TorReady(_route!.route)));
      add(const OnServerCheck());
      return;
    }
    final oldRoute = _route;
    final generation = ++_routeGeneration;
    _route = null;
    if (oldRoute != null) {
      try {
        await oldRoute.close();
      } catch (error, stackTrace) {
        log.warning(
          'closing RecoverBull route failed',
          error: error,
          trace: stackTrace,
        );
      }
    }
    if (isClosed || _closingBloc) return;
    final preparation = _ensureRecoverBullTorSessionUsecase.execute(
      restartEmbedded: event.restart,
    );
    _pendingRoutePreparation = preparation;
    final result = await preparation;
    if (identical(_pendingRoutePreparation, preparation)) {
      _pendingRoutePreparation = null;
    }
    if (isClosed || _closingBloc || generation != _routeGeneration) {
      if (result case Ok(:final value)) await value.closeQuietly();
      return;
    }
    switch (result) {
      case Ok(:final value):
        _route = value;
        final connection = tor.TorReady(value.route);
        if (isClosed || _closingBloc || generation != _routeGeneration) {
          await value.closeQuietly();
          return;
        }
        emit(state.copyWith(torConnection: connection));
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
  }

  Future<void> _onServerCheck(
    OnServerCheck event,
    Emitter<RecoverBullState> emit,
  ) async {
    final generation = _routeGeneration;
    final route = _route;
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
      if (isClosed || _closingBloc || generation != _routeGeneration) {
        if (!isClosed && !_closingBloc && generation != _routeGeneration) {
          add(const OnServerCheck());
        }
        return;
      }

      switch (result) {
        case Err(:final failure):
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
      }
    } catch (e) {
      if (isClosed || _closingBloc || generation != _routeGeneration) {
        if (!isClosed && !_closingBloc && generation != _routeGeneration) {
          add(const OnServerCheck());
        }
        return;
      }
      log.severe(error: e, trace: StackTrace.current);
      emit(
        state.copyWith(
          failure: const RecoverBullUnexpectedFailure(),
          keyServerStatus: KeyServerStatus.offline,
        ),
      );
    }
  }

  Future<void> _onVaultPasswordSet(
    OnVaultPasswordSet event,
    Emitter<RecoverBullState> emit,
  ) async {
    switch (state.flow) {
      case RecoverBullFlow.secureVault:
        if (_pendingProviderVault != null) {
          emit(state.copyWith(failure: const VaultProviderSaveFailure()));
        } else {
          emit(state.copyWith(vaultPassword: event.password));
        }
      default:
        if (state.vault == null) {
          emit(state.copyWith(failure: const VaultNotSetFailure()));
          return;
        }
        await _onFetchVaultKey(state.vault!, event.password, emit);
    }
  }

  Future<void> _onVaultProviderSelection(
    OnVaultProviderSelection event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          isLoading: true,
          failure: null,
          vault: null,
          vaultProvider: null,
        ),
      );

      switch (state.flow) {
        case RecoverBullFlow.secureVault:
          if (_pendingProviderVault case final pendingVault?) {
            await _saveVaultToProvider(pendingVault, event.provider, emit);
          } else {
            if (state.vaultPassword == null) {
              emit(state.copyWith(failure: const PasswordNotSetFailure()));
              return;
            }
            await _createAndStoreVault(
              event.provider,
              state.vaultPassword!,
              emit,
            );
          }
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
      if (!isClosed && !_closingBloc && !emit.isDone) {
        emit(state.copyWith(failure: const RecoverBullUnexpectedFailure()));
      }
    } finally {
      if (!isClosed && !_closingBloc && !emit.isDone) {
        emit(state.copyWith(isLoading: false));
      }
    }
  }

  Future<void> _onVaultSelection(
    OnVaultSelection event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, failure: null));

      switch (event.provider) {
        case VaultProvider.googleDrive:
          final connected = await _connectToGoogleDriveUsecase.execute();
          if (isClosed || _closingBloc || emit.isDone) return;
          if (connected case Err(:final failure)) {
            emit(state.copyWith(failure: _selectFailure(failure)));
            return;
          }
          final latest = await _fetchLatestGoogleDriveVaultUsecase.execute();
          if (isClosed || _closingBloc || emit.isDone) return;
          switch (latest) {
            case Ok(:final value):
              emit(state.copyWith(vault: value));
            case Err(:final failure):
              emit(state.copyWith(failure: _selectFailure(failure)));
          }
        case VaultProvider.customLocation:
          final picked = await _pickVaultUsecase.execute();
          if (isClosed || _closingBloc || emit.isDone) return;
          switch (picked) {
            case Ok(:final value):
              emit(state.copyWith(vault: value));
            case Err(:final failure):
              emit(state.copyWith(failure: _selectFailure(failure)));
          }
        case VaultProvider.iCloud:
          log.warning('iCloud, not supported yet');
          emit(state.copyWith(failure: const SelectVaultFailure()));
          return;
      }
      log.fine('Vault selected');
    } finally {
      if (!isClosed && !_closingBloc && !emit.isDone) {
        emit(state.copyWith(isLoading: false));
      }
    }
  }

  Future<void> _onVaultCreation(
    OnVaultCreation event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, failure: null));

      if (_pendingProviderVault case final pendingVault?) {
        await _saveVaultToProvider(pendingVault, event.provider, emit);
        return;
      }

      await _createAndStoreVault(event.provider, event.password, emit);
    } finally {
      if (!isClosed && !_closingBloc && !emit.isDone) {
        emit(state.copyWith(isLoading: false));
      }
    }
  }

  Future<void> _createAndStoreVault(
    VaultProvider provider,
    String password,
    Emitter<RecoverBullState> emit,
  ) async {
    if (provider == VaultProvider.iCloud) {
      emit(state.copyWith(failure: const SelectVaultFailure()));
      return;
    }

    final EncryptedVault vault;
    final String vaultKey;
    final created = await _createEncryptedVaultUsecase.execute();
    if (isClosed || _closingBloc || emit.isDone) return;
    switch (created) {
      case Ok(:final value):
        vault = value.vault;
        vaultKey = value.vaultKey;
      case Err():
        emit(state.copyWith(failure: const VaultCreationFailure()));
        return;
    }

    final connection = await _checkKeyServerConnectionUsecase.execute();
    if (isClosed || _closingBloc || emit.isDone) return;
    switch (connection) {
      case Ok(value: true):
        break;
      case Ok():
        emit(state.copyWith(failure: const KeyServerConnectionFailure()));
        return;
      case Err(:final failure):
        emit(state.copyWith(failure: _storeKeyFailure(failure)));
        return;
    }

    final keyStored = await _storeVaultKeyIntoServerUsecase.execute(
      password: password,
      vault: vault,
      vaultKey: vaultKey,
      route: _route,
    );
    if (isClosed || _closingBloc || emit.isDone) return;
    if (keyStored case Err(:final failure)) {
      emit(state.copyWith(failure: _storeKeyFailure(failure)));
      return;
    }

    // Only the encrypted vault crosses the provider retry boundary. The key and
    // password remain local to this operation and are never kept pending.
    emit(state.copyWith(failure: null, vaultPassword: null));
    _pendingProviderVault = vault;
    await _saveVaultToProvider(vault, provider, emit);
  }

  Future<void> _saveVaultToProvider(
    EncryptedVault vault,
    VaultProvider provider,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      switch (provider) {
        case VaultProvider.customLocation:
          final saved = await _saveFileToSystemUsecase.execute(
            content: vault.toFile(),
            filename: vault.filename,
          );
          if (isClosed || _closingBloc || emit.isDone) return;
          if (saved case Err()) {
            if (!isClosed && !_closingBloc && !emit.isDone) {
              emit(state.copyWith(failure: const VaultProviderSaveFailure()));
            }
            return;
          }
        case VaultProvider.googleDrive:
          final connected = await _connectToGoogleDriveUsecase.execute();
          if (isClosed || _closingBloc || emit.isDone) return;
          if (connected case Err()) {
            emit(state.copyWith(failure: const VaultProviderSaveFailure()));
            return;
          }
          final stored = await _saveToGoogleDriveUsecase.execute(vault);
          if (isClosed || _closingBloc || emit.isDone) return;
          if (stored case Err()) {
            if (!isClosed && !_closingBloc && !emit.isDone) {
              emit(state.copyWith(failure: const VaultProviderSaveFailure()));
            }
            return;
          }
        case VaultProvider.iCloud:
          log.warning('iCloud, not supported yet');
          if (!isClosed && !_closingBloc && !emit.isDone) {
            emit(state.copyWith(failure: const VaultProviderSaveFailure()));
          }
          return;
      }
    } catch (_) {
      log.warning('saving vault to provider failed with an exception');
      if (!isClosed && !_closingBloc && !emit.isDone) {
        emit(state.copyWith(failure: const VaultProviderSaveFailure()));
      }
      return;
    }

    try {
      await _registerMonitoredBackupUsecase?.execute(backupIdHex: vault.id);
    } catch (_) {
      // Local attempt monitoring is advisory after the external provider succeeded.
    }
    if (isClosed || _closingBloc || emit.isDone) {
      _pendingProviderVault = null;
      return;
    }
    try {
      await lifecycle?.markStored();
    } catch (_) {
      // Local lifecycle state is advisory after the external provider succeeded.
    }
    if (isClosed || _closingBloc || emit.isDone) {
      _pendingProviderVault = null;
      return;
    }
    emit(state.copyWith(failure: null, vault: vault, vaultProvider: provider));
    _pendingProviderVault = null;
    log.fine('Vault created and key stored in server');
  }

  Future<void> _onFetchVaultKey(
    EncryptedVault vault,
    String password,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      if (state.flow == RecoverBullFlow.secureVault) return;

      emit(state.copyWith(isLoading: true, vaultKey: null));

      final fetched = await _fetchVaultKeyFromServerUsecase.execute(
        vault: vault,
        password: password,
        route: _route,
      );
      if (isClosed || _closingBloc || emit.isDone) return;
      switch (fetched) {
        case Ok(:final value):
          emit(state.copyWith(vaultKey: value));
          log.fine('Vault key fetched from server');
          if (isClosed || _closingBloc || emit.isDone) return;
          await _onVaultDecryption(OnVaultDecryption(vaultKey: value), emit);
        case Err(:final failure):
          emit(state.copyWith(failure: _fetchKeyFailure(failure)));
      }
    } finally {
      if (!isClosed && !_closingBloc && !emit.isDone) {
        emit(state.copyWith(isLoading: false));
      }
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
        case RecoverBullFlow.viewVaultKey:
          emit(state.copyWith(decryptedVault: decryptedVault));
        case RecoverBullFlow.testVault:
          emit(state.copyWith(decryptedVault: decryptedVault));
          if (!await _isCurrentWalletVault(decryptedVault, emit)) return;
          try {
            await lifecycle?.markVerified();
          } catch (_) {
            log.warning('recoverbull.lifecycle.mark_verified_failed');
          }
          if (isClosed || _closingBloc || emit.isDone) return;
          emit(
            state.copyWith(
              isFlowFinished: true,
              isLoading: false,
              vaultKey: null,
              vaultPassword: null,
              decryptedVault: null,
            ),
          );
          return;
        case RecoverBullFlow.recoverVault:
          emit(state.copyWith(decryptedVault: decryptedVault));
          if (!await _isCurrentWalletVault(decryptedVault, emit)) return;
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
      if (!isClosed && !_closingBloc && !emit.isDone) {
        emit(state.copyWith(failure: const VaultDecryptionFailure()));
      }
    } finally {
      if (!isClosed && !_closingBloc && !emit.isDone) {
        emit(state.copyWith(isLoading: false));
      }
    }
  }

  Future<bool> _isCurrentWalletVault(
    DecryptedVault decryptedVault,
    Emitter<RecoverBullState> emit,
  ) async {
    final result = await verifyDecryptedVaultUsecase.execute(
      decryptedVault: decryptedVault,
    );
    if (result case Ok(value: VaultVerificationResult.match)) return true;
    if (state.flow == RecoverBullFlow.recoverVault) {
      switch (result) {
        case Ok(value: VaultVerificationResult.noCurrentWallet):
          return true;
        case Ok():
        case Err():
          break;
      }
    }
    emit(state.copyWith(failure: const VaultDecryptionFailure()));
    return false;
  }

  // Persists the recovered wallets, kicks off the real WalletBloc sync, and
  // marks the flow finished so `FetchVaultKeyPage` can navigate straight to
  // the wallet home. Replaces the deprecated dry-scan preview screen, which
  // showed a balance/tx preview gated behind a manual "Continue" button.
  Future<void> _restoreAndStart(
    DecryptedVault decryptedVault,
    Emitter<RecoverBullState> emit,
  ) async {
    final restored = await _restoreVaultUsecase.execute(
      decryptedVault: decryptedVault,
    );
    if (isClosed || _closingBloc || emit.isDone) return;
    switch (restored) {
      case Ok():
        try {
          await lifecycle?.markVerified();
        } catch (_) {
          log.warning('recoverbull.lifecycle.mark_verified_failed');
        }
        if (isClosed || _closingBloc || emit.isDone) return;
        try {
          await onWalletUpdated?.call();
        } catch (_) {
          log.warning('recoverbull.wallet_refresh.restore_failed');
        }
        if (isClosed || _closingBloc || emit.isDone) return;
        log.fine('Vault recovered');
        emit(
          state.copyWith(
            isFlowFinished: true,
            isLoading: false,
            vaultKey: null,
            vaultPassword: null,
            decryptedVault: null,
          ),
        );
      case Err():
        emit(
          state.copyWith(
            failure: const VaultRecoveryFailure(),
            isLoading: false,
          ),
        );
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
