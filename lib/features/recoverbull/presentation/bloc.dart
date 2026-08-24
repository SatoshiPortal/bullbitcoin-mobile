import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
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
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/connect_to_key_server_usecase.dart';
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
  final DecryptVaultUsecase _decryptVaultUsecase;
  final RestoreVaultUsecase _restoreVaultUsecase;
  final tor.EnsureTorReadyUsecase _ensureTorReadyUsecase;
  final tor.RetryTorConnectionUsecase _retryTorConnectionUsecase;
  final WalletBloc _walletBloc;
  final FetchLatestGoogleDriveVaultUsecase _fetchLatestGoogleDriveVaultUsecase;
  final UpdateLatestEncryptedVaultTestUsecase
  _updateLatestEncryptedVaultTestUsecase;
  final tor.WatchTorConnectionUsecase _watchTorConnectionUsecase;

  StreamSubscription<tor.TorConnectionState>? _torSubscription;

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
    required this._decryptVaultUsecase,
    required this._restoreVaultUsecase,
    required this._connectToGoogleDriveUsecase,
    required this._saveToGoogleDriveUsecase,
    required this._ensureTorReadyUsecase,
    required this._retryTorConnectionUsecase,
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

  @override
  Future<void> close() async {
    await _torSubscription?.cancel();
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
    if (state.torConnection is tor.TorReady &&
        next is tor.TorConnecting &&
        next.diagnostic == null) {
      return;
    }
    emit(state.copyWith(torConnection: next));

    // The stale-generation arm of `_onTorInitialization` returns without
    // dispatching a server check, so readiness that arrives through this stream
    // instead of through that call would otherwise never trigger one — leaving
    // the screen on "waiting" with no failure and no retry. Picking it up here
    // is what closes that dead end.
    if (next is tor.TorReady &&
        state.keyServerStatus == KeyServerStatus.unknown) {
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
    final connection = event.restart
        ? await _retryTorConnectionUsecase.execute()
        : await _ensureTorReadyUsecase.execute();
    if (isClosed) return;
    switch (connection) {
      case tor.TorReady(:final route):
        log.info(
          'Using ${route.source.name} Tor on port ${route.endpoint.port}',
        );
        emit(state.copyWith(torConnection: connection));
        add(const OnServerCheck());
      case tor.TorUnavailable(:final failure):
        log.severe(
          error: failure.logMessage ?? failure.runtimeType.toString(),
          trace: StackTrace.current,
        );
        emit(
          state.copyWith(
            failure: const TorNotStartedFailure(),
            keyServerStatus: KeyServerStatus.offline,
          ),
        );
      case tor.TorUninitialized() || tor.TorStopped() || tor.TorConnecting():
        // A newer retry generation replaced this operation. Its stream owns the
        // current state; the stale handler must not publish a failure.
        return;
    }
  }

  Future<void> _onServerCheck(
    OnServerCheck event,
    Emitter<RecoverBullState> emit,
  ) async {
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

      final isConnected = await _connectToKeyServerUsecase.execute(
        // Published before the call, so the screen shows which attempt is
        // actually in flight rather than which one already failed. Guarded:
        // the backoff outlives the screen when the user navigates away.
        onAttempt: (attempt) {
          if (isClosed) return;
          emit(state.copyWith(keyServerAttempt: attempt));
        },
      );

      if (!isConnected) {
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
      } else {
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
      log.severe(error: e, trace: StackTrace.current);
      emit(
        state.copyWith(
          failure: RecoverBullUnexpectedFailure(e.toString()),
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
              emit(state.copyWith(vault: value));
            case Err(:final failure):
              emit(state.copyWith(failure: _selectFailure(failure)));
          }
        case VaultProvider.customLocation:
          switch (await _pickVaultUsecase.execute()) {
            case Ok(:final value):
              emit(state.copyWith(vault: value));
            case Err(:final failure):
              emit(state.copyWith(failure: _selectFailure(failure)));
          }
        case VaultProvider.iCloud:
          log.warning('iCloud, not supported yet');
      }
      log.fine('Vault selected');
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onVaultCreation(
    OnVaultCreation event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));

      final EncryptedVault vault;
      final String vaultKey;
      switch (await _createEncryptedVaultUsecase.execute()) {
        case Ok(:final value):
          vault = value.vault;
          vaultKey = value.vaultKey;
        case Err():
          emit(state.copyWith(failure: const VaultCreationFailure()));
          return;
      }

      final isConnected = await _checkKeyServerConnectionUsecase.execute();
      if (!isConnected) {
        emit(state.copyWith(failure: const KeyServerConnectionFailure()));
        return;
      }

      switch (event.provider) {
        case VaultProvider.customLocation:
          final saved = await _saveFileToSystemUsecase.execute(
            content: vault.toFile(),
            filename: vault.filename,
          );
          if (saved case Err()) {
            emit(state.copyWith(failure: const VaultCreationFailure()));
            return;
          }
        case VaultProvider.googleDrive:
          final connected = await _connectToGoogleDriveUsecase.execute();
          if (connected case Err()) {
            emit(state.copyWith(failure: const VaultCreationFailure()));
            return;
          }
          final stored = await _saveToGoogleDriveUsecase.execute(vault);
          if (stored case Err()) {
            emit(state.copyWith(failure: const VaultCreationFailure()));
            return;
          }
        case VaultProvider.iCloud:
          log.warning('iCloud, not supported yet');
      }

      final keyStored = await _storeVaultKeyIntoServerUsecase.execute(
        password: event.password,
        vault: vault,
        vaultKey: vaultKey,
      );
      if (keyStored case Err(:final failure)) {
        // Keep the typed key-server detail (rate-limit cooldown, invalid
        // credentials) instead of collapsing it to the generic creation error.
        emit(state.copyWith(failure: _storeKeyFailure(failure)));
        return;
      }

      emit(state.copyWith(vault: vault, vaultProvider: event.provider));
      log.fine('Vault created and key stored in server');
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onFetchVaultKey(
    OnVaultFetchKey event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      if (state.flow == RecoverBullFlow.secureVault) return;

      emit(state.copyWith(isLoading: true, vaultKey: null));

      switch (await _fetchVaultKeyFromServerUsecase.execute(
        vault: event.vault,
        password: event.password,
      )) {
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

  Future<void> _onClearError(
    OnClearError event,
    Emitter<RecoverBullState> emit,
  ) async {
    emit(state.copyWith(failure: null));
  }

  // Maps a core failure surfaced while selecting/fetching a vault.
  RecoverBullFailure _selectFailure(RecoverBullCoreFailure failure) =>
      switch (failure) {
        InvalidVaultFileFailure() => const InvalidVaultFileFormatFailure(),
        _ => const SelectVaultFailure(),
      };

  // Maps a core failure surfaced while fetching the vault key from the server.
  RecoverBullFailure _fetchKeyFailure(RecoverBullCoreFailure failure) =>
      switch (failure) {
        KeyServerInvalidCredentialsFailure() =>
          const InvalidVaultCredentialsFailure(),
        KeyServerRejectedFailure() => const InvalidVaultCredentialsFailure(),
        KeyServerRateLimitedFailure(:final retryIn) => VaultRateLimitedFailure(
          retryIn: retryIn ?? Duration.zero,
        ),
        KeyServerUnavailableFailure() => const VaultKeyFetchFailure(),
        _ => RecoverBullUnexpectedFailure(failure.logMessage),
      };

  // Maps a core failure surfaced while storing the vault key during creation.
  // Mirrors [_fetchKeyFailure] for the shared key-server cases (so a 429
  // cooldown or invalid credentials still reach the user) but falls back to the
  // creation-specific error instead of the generic unexpected one.
  RecoverBullFailure _storeKeyFailure(RecoverBullCoreFailure failure) =>
      switch (failure) {
        KeyServerInvalidCredentialsFailure() =>
          const InvalidVaultCredentialsFailure(),
        KeyServerRejectedFailure() => const InvalidVaultCredentialsFailure(),
        KeyServerRateLimitedFailure(:final retryIn) => VaultRateLimitedFailure(
          retryIn: retryIn ?? Duration.zero,
        ),
        KeyServerUnavailableFailure() => const KeyServerConnectionFailure(),
        _ => const VaultCreationFailure(),
      };
}
