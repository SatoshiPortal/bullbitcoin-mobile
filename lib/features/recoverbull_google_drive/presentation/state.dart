import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class RecoverBullGoogleDriveState with _$RecoverBullGoogleDriveState {
  const factory RecoverBullGoogleDriveState({
    @Default(false) bool isLoading,
    String? errorKey,
    @Default([]) List<DriveFileMetadata> driveMetadata,
    @Default(null) EncryptedVault? selectedVault,
  }) = _RecoverBullSelectVaultState;

  const RecoverBullGoogleDriveState._();
}
