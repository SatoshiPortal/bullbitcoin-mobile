import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_vault_key_with_status_from_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/update_latest_encrypted_backup_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/tor_status_usecase.dart';
import 'package:bb_mobile/core/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/recoverbull/presentation/telemetry/recoverbull_telemetry_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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
  final CheckServerConnectionUsecase _checkKeyServerConnectionUsecase;
  final DecryptVaultUsecase _decryptVaultUsecase;
  final RestoreVaultUsecase _restoreVaultUsecase;
  final InitTorUsecase _initializeTorUsecase;
  final WalletBloc _walletBloc;
  final FetchLatestGoogleDriveVaultUsecase _fetchLatestGoogleDriveVaultUsecase;
  final UpdateLatestEncryptedVaultTestUsecase
  _updateLatestEncryptedVaultTestUsecase;
  final TorStatusUsecase _torStatusUsecase;
  final TorConfigPort _torConfigPort;
  final FetchVaultKeyWithStatusFromServerUsecase
  _fetchVaultKeyWithStatusFromServerUsecase;
  final RecoverbullTelemetryCubit _recoverbullTelemetryCubit;

  RecoverBullBloc({
    required RecoverBullFlow flow,
    EncryptedVault? preSelectedVault,
    required this._pickVaultUsecase,
    required this._saveFileToSystemUsecase,
    required this._createEncryptedVaultUsecase,
    required this._storeVaultKeyIntoServerUsecase,
    required this._checkKeyServerConnectionUsecase,
    required this._decryptVaultUsecase,
    required this._restoreVaultUsecase,
    required this._connectToGoogleDriveUsecase,
    required this._saveToGoogleDriveUsecase,
    required this._initializeTorUsecase,
    required this._walletBloc,
    required this._fetchLatestGoogleDriveVaultUsecase,
    required this._updateLatestEncryptedVaultTestUsecase,
    required this._torStatusUsecase,
    required this._torConfigPort,
    required this._fetchVaultKeyWithStatusFromServerUsecase,
    required this._recoverbullTelemetryCubit,
  }) : super(RecoverBullState(flow: flow, vault: preSelectedVault)) {
    on<OnVaultProviderSelection>(_onVaultProviderSelection);
    on<OnVaultSelection>(_onVaultSelection);
    on<OnVaultPasswordSet>(_onVaultPasswordSet);
    on<OnVaultCreation>(_onVaultCreation);
    on<OnVaultDecryption>(_onVaultDecryption);
    on<OnServerCheck>(_onServerCheck);
    on<OnTorInitialization>(_onTorInitialization);
    on<OnClearError>(_onClearError);
  }

  Future<void> _onTorInitialization(
    OnTorInitialization event,
    Emitter<RecoverBullState> emit,
  ) async {
    // Tor is a separate core domain that still throws; the bloc is its boundary.
    try {
      final externalTorConfig = await _torConfigPort
          .getAvailableExternalTorConfig();

      if (externalTorConfig == null) {
        await _initializeTorUsecase.execute();
      } else {
        log.info('Using external Tor proxy on port ${externalTorConfig.port}');
      }

      add(const OnServerCheck());
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      emit(
        state.copyWith(
          failure: const TorNotStartedFailure(),
          keyServerStatus: KeyServerStatus.offline,
        ),
      );
    }
  }

  Future<void> _onServerCheck(
    OnServerCheck event,
    Emitter<RecoverBullState> emit,
  ) async {
    // _torStatusUsecase (tor domain) still throws; the bloc is its boundary.
    try {
      final torStatus = await _torStatusUsecase.execute();
      emit(state.copyWith(torStatus: torStatus));

      emit(state.copyWith(keyServerStatus: KeyServerStatus.connecting));

      var isConnected = false;
      const retries = 3;
      int attempt = 1;
      for (; attempt <= retries; attempt++) {
        final delay = Duration(seconds: attempt);
        await Future.delayed(delay);
        isConnected = await _checkKeyServerConnectionUsecase.execute();
        if (isConnected) break;
      }

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
        log.fine('Recoverbull server ready after $attempt attempts');
        emit(
          state.copyWith(
            keyServerStatus: KeyServerStatus.online,
            torStatus: TorStatus.online,
          ),
        );
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

      // Telemetry: register this backup as monitored WITHOUT counting an
      // attempt — the server does not count stores, so counting one here
      // would mask one attacker probe per window. Unawaited, never blocks
      // the creation flow.
      unawaited(
        _recoverbullTelemetryCubit.registerMonitoredBackup(
          backupIdHex: vault.id,
        ),
      );

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

      switch (await _fetchVaultKeyWithStatusFromServerUsecase.execute(
        vault: event.vault,
        password: event.password,
      )) {
        case Ok(:final value):
          emit(state.copyWith(vaultKey: value.vaultKey));
          log.fine('Vault key fetched from server');
          // Telemetry: record this device's own operation and surface an
          // immediate suspicious-activity alert when the server's counters
          // exceed it. Unawaited, never blocks the recovery flow.
          unawaited(
            _recoverbullTelemetryCubit.recordLocalAttempt(
              backupIdHex: event.vault.id,
              attemptStatus: value.attemptStatus,
            ),
          );
          await _onVaultDecryption(
            OnVaultDecryption(vaultKey: value.vaultKey),
            emit,
          );
        case Err(:final failure):
          // The targeted per-identifier lockout on the user's own fetch is
          // an alarm signal: someone may be probing or griefing this backup.
          if (failure is KeyServerTargetedRateLimitedFailure) {
            unawaited(
              _recoverbullTelemetryCubit.reportTargetedLockout(
                backupIdHex: event.vault.id,
              ),
            );
          }
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
        KeyServerTargetedRateLimitedFailure(:final retryIn) =>
          VaultRateLimitedFailure(retryIn: retryIn ?? Duration.zero),
        // Global 429 / capacity 503 are service pressure, not an attack:
        // surface them as unavailability, never as a lockout alarm.
        KeyServerOverloadedFailure() => const VaultKeyFetchFailure(),
        KeyServerCapacityFailure() => const VaultKeyFetchFailure(),
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
        KeyServerTargetedRateLimitedFailure(:final retryIn) =>
          VaultRateLimitedFailure(retryIn: retryIn ?? Duration.zero),
        KeyServerOverloadedFailure() => const KeyServerConnectionFailure(),
        KeyServerCapacityFailure() => const KeyServerConnectionFailure(),
        KeyServerUnavailableFailure() => const KeyServerConnectionFailure(),
        _ => const VaultCreationFailure(),
      };
}
