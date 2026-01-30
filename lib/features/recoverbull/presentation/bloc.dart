import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
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
import 'package:bb_mobile/core/recoverbull/errors.dart' as core;
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/tor_status_usecase.dart';
import 'package:bb_mobile/core/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_wallet_status_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/recoverbull/errors.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bloc.freezed.dart';
part 'event.dart';
part 'state.dart';

class RecoverBullBloc extends Bloc<RecoverBullEvent, RecoverBullState> {
  final _pickVaultUsecase = PickVaultUsecase();
  final _saveFileToSystemUsecase = SaveFileToSystemUsecase();
  final ConnectToGoogleDriveUsecase _connectToGoogleDriveUsecase;
  final SaveVaultToGoogleDriveUsecase _saveToGoogleDriveUsecase;
  final CreateEncryptedVaultUsecase _createEncryptedVaultUsecase;
  final StoreVaultKeyIntoServerUsecase _storeVaultKeyIntoServerUsecase;
  final CheckServerConnectionUsecase _checkKeyServerConnectionUsecase;
  final FetchVaultKeyFromServerUsecase _fetchVaultKeyFromServerUsecase;
  final DecryptVaultUsecase _decryptVaultUsecase;
  final RestoreVaultUsecase _restoreVaultUsecase;
  final InitTorUsecase _initializeTorUsecase;
  final TheDirtyUsecase _checkWalletStatusUsecase;
  final TheDirtyLiquidUsecase _checkLiquidWalletStatusUsecase;
  final WalletBloc _walletBloc;
  final FetchLatestGoogleDriveVaultUsecase _fetchLatestGoogleDriveVaultUsecase;
  final UpdateLatestEncryptedVaultTestUsecase
  _updateLatestEncryptedVaultTestUsecase;
  final TorStatusUsecase _torStatusUsecase;
  final TorConfigPort _torConfigPort;

  RecoverBullBloc({
    required RecoverBullFlow flow,
    EncryptedVault? preSelectedVault,
    required CreateEncryptedVaultUsecase createEncryptedVaultUsecase,
    required StoreVaultKeyIntoServerUsecase storeVaultKeyIntoServerUsecase,
    required CheckServerConnectionUsecase checkKeyServerConnectionUsecase,
    required FetchVaultKeyFromServerUsecase fetchVaultKeyFromServerUsecase,
    required DecryptVaultUsecase decryptVaultUsecase,
    required RestoreVaultUsecase restoreVaultUsecase,
    required ConnectToGoogleDriveUsecase connectToGoogleDriveUsecase,
    required SaveVaultToGoogleDriveUsecase saveToGoogleDriveUsecase,
    required InitTorUsecase initializeTorUsecase,
    required TheDirtyUsecase checkWalletStatusUsecase,
    required TheDirtyLiquidUsecase checkLiquidWalletStatusUsecase,
    required WalletBloc walletBloc,
    required FetchLatestGoogleDriveVaultUsecase
    fetchLatestGoogleDriveVaultUsecase,
    required UpdateLatestEncryptedVaultTestUsecase
    updateLatestEncryptedVaultTestUsecase,
    required TorStatusUsecase torStatusUsecase,
    required TorConfigPort torConfigPort,
  }) : _createEncryptedVaultUsecase = createEncryptedVaultUsecase,
       _storeVaultKeyIntoServerUsecase = storeVaultKeyIntoServerUsecase,
       _checkKeyServerConnectionUsecase = checkKeyServerConnectionUsecase,
       _fetchVaultKeyFromServerUsecase = fetchVaultKeyFromServerUsecase,
       _decryptVaultUsecase = decryptVaultUsecase,
       _restoreVaultUsecase = restoreVaultUsecase,
       _connectToGoogleDriveUsecase = connectToGoogleDriveUsecase,
       _saveToGoogleDriveUsecase = saveToGoogleDriveUsecase,
       _initializeTorUsecase = initializeTorUsecase,
       _checkWalletStatusUsecase = checkWalletStatusUsecase,
       _checkLiquidWalletStatusUsecase = checkLiquidWalletStatusUsecase,
       _walletBloc = walletBloc,
       _fetchLatestGoogleDriveVaultUsecase = fetchLatestGoogleDriveVaultUsecase,
       _updateLatestEncryptedVaultTestUsecase =
           updateLatestEncryptedVaultTestUsecase,
       _torStatusUsecase = torStatusUsecase,
       _torConfigPort = torConfigPort,
       super(RecoverBullState(flow: flow, vault: preSelectedVault)) {
    on<OnVaultProviderSelection>(_onVaultProviderSelection);
    on<OnVaultSelection>(_onVaultSelection);
    on<OnVaultPasswordSet>(_onVaultPasswordSet);
    on<OnVaultCreation>(_onVaultCreation);
    on<OnVaultDecryption>(_onVaultDecryption);
    on<OnVaultCheckStatus>(_onVaultCheckStatus);
    on<OnVaultRecovery>(_onVaultRecovery);
    on<OnServerCheck>(_onServerCheck);
    on<OnTorInitialization>(_onTorInitialization);
    on<OnClearError>(_onClearError);
  }

  Future<void> _onTorInitialization(
    OnTorInitialization event,
    Emitter<RecoverBullState> emit,
  ) async {
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
          error: TorNotStartedError(),
          keyServerStatus: KeyServerStatus.offline,
        ),
      );
    }
  }

  Future<void> _onServerCheck(
    OnServerCheck event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      final torStatus = await _torStatusUsecase.execute();
      emit(state.copyWith(torStatus: torStatus));

      emit(state.copyWith(keyServerStatus: KeyServerStatus.connecting));

      var isConnected = false;
      const retries = 3;
      int attempt = 1;
      for (; attempt <= retries; attempt++) {
        try {
          final delay = Duration(seconds: attempt);
          await Future.delayed(delay);
          isConnected = await _checkKeyServerConnectionUsecase.execute();
          if (isConnected) break;
        } catch (e) {
          log.config('Recoverbull server is not ready $attempt attempt: $e');
        }
      }

      if (!isConnected) {
        log.severe(
          error: 'Recoverbull server is not ready after $retries retries',
          trace: StackTrace.current,
        );
        emit(
          state.copyWith(
            error: KeyServerConnectionError(),
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
          error: UnexpectedError(),
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
          emit(state.copyWith(error: VaultIsNotSetError()));
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
            emit(state.copyWith(error: PasswordIsNotSetError()));
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
      emit(state.copyWith(error: UnexpectedError()));
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
          await _connectToGoogleDriveUsecase.execute();
          final encryptedVault = await _fetchLatestGoogleDriveVaultUsecase
              .execute();
          emit(state.copyWith(vault: encryptedVault));
          return;
        case VaultProvider.customLocation:
          final vault = await _pickVaultUsecase.execute();
          emit(state.copyWith(vault: vault));
        case VaultProvider.iCloud:
          log.warning('iCloud, not supported yet');
      }
      log.fine('Vault selected');
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      switch (e) {
        case core.InvalidVaultFileError():
          emit(state.copyWith(error: InvalidVaultFileFormatError()));
        default:
          emit(state.copyWith(error: SelectVaultError()));
      }
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

      final (vault: vault, vaultKey: vaultKey) =
          await _createEncryptedVaultUsecase.execute();

      final isConnected = await _checkKeyServerConnectionUsecase.execute();
      if (!isConnected) {
        emit(state.copyWith(error: KeyServerConnectionError()));
      }

      switch (event.provider) {
        case VaultProvider.customLocation:
          await _saveFileToSystemUsecase.execute(
            content: vault.toFile(),
            filename: EncryptedVault(file: vault.toFile()).filename,
          );
        case VaultProvider.googleDrive:
          await _connectToGoogleDriveUsecase.execute();
          await _saveToGoogleDriveUsecase.execute(vault);
        case VaultProvider.iCloud:
          log.warning('iCloud, not supported yet');
      }

      await _storeVaultKeyIntoServerUsecase.execute(
        password: event.password,
        vault: vault,
        vaultKey: vaultKey,
      );

      emit(state.copyWith(vault: vault, vaultProvider: event.provider));
      log.fine('Vault created and key stored in server');
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      emit(state.copyWith(error: VaultCreationError()));
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

      final vaultKey = await _fetchVaultKeyFromServerUsecase.execute(
        vault: event.vault,
        password: event.password,
      );

      emit(state.copyWith(vaultKey: vaultKey));
      log.fine('Vault key fetched from server');

      await _onVaultDecryption(OnVaultDecryption(vaultKey: vaultKey), emit);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      switch (e) {
        case core.InvalidCredentialsError():
          emit(state.copyWith(error: InvalidVaultCredentials()));
        case core.RateLimitedError():
          emit(
            state.copyWith(error: VaultRateLimitedError(retryIn: e.retryIn)),
          );
        case core.KeyServerErrorRejected():
          emit(state.copyWith(error: InvalidVaultCredentials()));
        case core.KeyServerErrorServiceUnavailable():
          emit(state.copyWith(error: VaultKeyFetchError()));
        default:
          emit(state.copyWith(error: UnexpectedError()));
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
      emit(state.copyWith(error: VaultIsNotSetError()));
      return;
    }

    final vaultKey = event.vaultKey;
    final vault = state.vault!;

    try {
      emit(state.copyWith(isLoading: true));

      final decryptedVault = _decryptVaultUsecase.execute(
        vault: vault,
        vaultKey: vaultKey,
      );

      switch (state.flow) {
        case RecoverBullFlow.viewVaultKey || RecoverBullFlow.testVault:
          await _updateLatestEncryptedVaultTestUsecase.execute(
            decryptedVault: decryptedVault,
          );
          emit(state.copyWith(decryptedVault: decryptedVault));
        case RecoverBullFlow.recoverVault:
          emit(state.copyWith(decryptedVault: decryptedVault));
          await _updateLatestEncryptedVaultTestUsecase.execute(
            decryptedVault: decryptedVault,
          );
          await _onVaultCheckStatus(
            OnVaultCheckStatus(decryptedVault: decryptedVault),
            emit,
          );
        case RecoverBullFlow.secureVault:
          throw UnimplementedError();
        case RecoverBullFlow.settings:
          throw UnimplementedError();
      }

      emit(state.copyWith(vaultKey: vaultKey));
      log.fine('Vault decrypted');
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      emit(state.copyWith(error: VaultDecryptionError()));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onVaultCheckStatus(
    OnVaultCheckStatus event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));

      final mnemonic = bip39.Mnemonic.fromWords(
        words: event.decryptedVault.mnemonic,
      );

      final bip84Status = await _checkWalletStatusUsecase(
        mnemonic: mnemonic,
        scriptType: ScriptType.bip84,
      );
      emit(state.copyWith(bip84Status: bip84Status));
      log.fine('Vault BIP84 status checked');

      final liquidStatus = await _checkLiquidWalletStatusUsecase(
        mnemonic: mnemonic,
      );
      emit(state.copyWith(liquidStatus: liquidStatus));
      log.fine('Vault Liquid status checked');
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      emit(state.copyWith(error: VaultCheckStatusError()));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onVaultRecovery(
    OnVaultRecovery event,
    Emitter<RecoverBullState> emit,
  ) async {
    if (state.decryptedVault == null) {
      emit(state.copyWith(error: DecryptedVaultIsNotSetError()));
      return;
    }
    if (state.flow != RecoverBullFlow.recoverVault) {
      emit(state.copyWith(error: InvalidFlowError()));
      return;
    }

    try {
      emit(state.copyWith(isLoading: true));

      await _restoreVaultUsecase.execute(decryptedVault: state.decryptedVault!);
      _walletBloc.add(const WalletStarted());
      log.fine('Vault recovered');
      emit(state.copyWith(isFlowFinished: true));
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      emit(state.copyWith(error: VaultRecoveryError()));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onClearError(
    OnClearError event,
    Emitter<RecoverBullState> emit,
  ) async {
    emit(state.copyWith(error: null));
  }
}
