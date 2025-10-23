import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_key_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/recoverbull/errors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bloc.freezed.dart';
part 'event.dart';
part 'state.dart';

class RecoverBullBloc extends Bloc<RecoverBullEvent, RecoverBullState> {
  final _pickVaultUsecase = PickVaultUsecase();
  final _saveFileToSystemUsecase = SaveFileToSystemUsecase();
  final _connectToGoogleDriveUsecase = ConnectToGoogleDriveUsecase();
  final _saveToGoogleDriveUsecase = SaveToGoogleDriveUsecase();
  final CreateEncryptedVaultUsecase _createEncryptedVaultUsecase;
  final StoreVaultKeyIntoServerUsecase _storeVaultKeyIntoServerUsecase;
  final CheckKeyServerConnectionUsecase _checkKeyServerConnectionUsecase;
  final FetchVaultKeyFromServerUsecase _fetchVaultKeyFromServerUsecase;
  final DecryptVaultUsecase _decryptVaultUsecase;
  final RestoreVaultUsecase _restoreVaultUsecase;

  RecoverBullBloc({
    required RecoverBullFlow flow,
    required CreateEncryptedVaultUsecase createEncryptedVaultUsecase,
    required StoreVaultKeyIntoServerUsecase storeVaultKeyIntoServerUsecase,
    required CheckKeyServerConnectionUsecase checkKeyServerConnectionUsecase,
    required FetchVaultKeyFromServerUsecase fetchVaultKeyFromServerUsecase,
    required DecryptVaultUsecase decryptVaultUsecase,
    required RestoreVaultUsecase restoreVaultUsecase,
  }) : _createEncryptedVaultUsecase = createEncryptedVaultUsecase,
       _storeVaultKeyIntoServerUsecase = storeVaultKeyIntoServerUsecase,
       _checkKeyServerConnectionUsecase = checkKeyServerConnectionUsecase,
       _fetchVaultKeyFromServerUsecase = fetchVaultKeyFromServerUsecase,
       _decryptVaultUsecase = decryptVaultUsecase,
       _restoreVaultUsecase = restoreVaultUsecase,
       super(RecoverBullState(flow: flow)) {
    on<OnVaultProviderSelection>(_onVaultProviderSelection);
    on<OnVaultSelection>(_onVaultSelection);
    on<OnVaultPasswordSet>(_onVaultPasswordSet);
    on<OnVaultCreation>(_onVaultCreation);
  }

  Future<void> _onVaultPasswordSet(
    OnVaultPasswordSet event,
    Emitter<RecoverBullState> emit,
  ) async {
    switch (state.flow) {
      case RecoverBullFlow.secureVault:
        emit(state.copyWith(vaultPassword: event.password));
      default:
        if (state.vault == null) throw VaultIsNotSetError();
        emit(state.copyWith(vaultPassword: event.password));

        await _onFetchVaultKey(
          OnFetchVaultKey(vault: state.vault!, password: event.password),
          emit,
        );
    }
  }

  Future<void> _onVaultProviderSelection(
    OnVaultProviderSelection event,
    Emitter<RecoverBullState> emit,
  ) async {
    switch (state.flow) {
      case RecoverBullFlow.secureVault:
        if (state.vaultPassword == null) throw PasswordIsNotSetError();

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
    }
  }

  Future<void> _onVaultSelection(
    OnVaultSelection event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      switch (event.provider) {
        case VaultProvider.googleDrive:
          // TODO(azad): Implement the logic to list the vaults from drive
          // the user should be able to select the vault, check the amount before recover it.
          // Maybe allow this only for recovery.
          return;
        case VaultProvider.customLocation:
          final vault = await _pickVaultUsecase.execute();
          emit(state.copyWith(vault: vault));
        case VaultProvider.iCloud:
          log.warning('iCloud, not supported yet');
      }
    } catch (e) {
      log.severe('Error selecting vault: $e');
      emit(state.copyWith(error: SelectVaultError()));
    }
  }

  Future<void> _onVaultCreation(
    OnVaultCreation event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      final (vault: vault, vaultKey: vaultKey) =
          await _createEncryptedVaultUsecase.execute();

      switch (event.provider) {
        case VaultProvider.customLocation:
          await _saveFileToSystemUsecase.execute(
            content: vault.toFile(),
            filename: EncryptedVault(file: vault.toFile()).filename,
          );
        case VaultProvider.googleDrive:
          await _connectToGoogleDriveUsecase.execute();
          await _saveToGoogleDriveUsecase.execute(vault.toFile());
        case VaultProvider.iCloud:
          log.warning('iCloud, not supported yet');
      }

      emit(state.copyWith(isLoading: true));

      await _checkKeyServerConnectionUsecase.execute();

      await _storeVaultKeyIntoServerUsecase.execute(
        password: event.password,
        vault: vault,
        vaultKey: vaultKey,
      );

      emit(state.copyWith(vault: vault));
      log.fine('Vault created and key stored in server');
    } catch (e) {
      log.severe('$OnVaultCreation on ${event.provider.name}: $e');
      emit(state.copyWith(error: BullError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onFetchVaultKey(
    OnFetchVaultKey event,
    Emitter<RecoverBullState> emit,
  ) async {
    try {
      if (state.flow == RecoverBullFlow.secureVault) {
        // TODO(azad): throw?
        return;
      }

      emit(state.copyWith(isLoading: true));
      await _checkKeyServerConnectionUsecase.execute();
      final vaultKey = await _fetchVaultKeyFromServerUsecase.execute(
        vault: event.vault,
        password: event.password,
      );

      // Ensure the key can decrypt the vault
      final decryptedVault = _decryptVaultUsecase.execute(
        vault: event.vault,
        vaultKey: vaultKey,
      );

      switch (state.flow) {
        case RecoverBullFlow.viewVaultKey || RecoverBullFlow.testVault:
          emit(
            state.copyWith(vaultKey: vaultKey, decryptedVault: decryptedVault),
          );
        case RecoverBullFlow.recoverVault:
          await _restoreVaultUsecase.execute(decryptedVault: decryptedVault);
          emit(state.copyWith(decryptedVault: decryptedVault));
        case RecoverBullFlow.secureVault:
          return;
      }

      emit(state.copyWith(vaultKey: vaultKey));
      log.fine('Vault key fetched from server');
    } catch (e) {
      log.severe('Error fetching vault key: $e');
      emit(state.copyWith(error: BullError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
