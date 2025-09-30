import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class RecoverBullSelectVaultState with _$RecoverBullSelectVaultState {
  const factory RecoverBullSelectVaultState({
    @Default(null) BackupProviderType? selectedProvider,
    @Default(false) bool isLoading,
    @Default(false) bool isSelectingVault,
    RecoverBullSelectVaultError? error,
    @Default([]) List<DriveFileMetadata> driveMetadata,
    @Default(null) EncryptedVault? selectedVault,
    @Default(null) ({BigInt satoshis, int transactions})? walletStatus,
  }) = _RecoverBullSelectVaultState;

  const RecoverBullSelectVaultState._();
}
