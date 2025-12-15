import 'package:bb_mobile/core_deprecated/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class RecoverBullGoogleDriveState with _$RecoverBullGoogleDriveState {
  const factory RecoverBullGoogleDriveState({
    @Default(false) bool isLoading,
    RecoverBullGoogleDriveError? error,
    @Default([]) List<DriveFileMetadata> driveMetadata,
    @Default(null) EncryptedVault? selectedVault,
  }) = _RecoverBullSelectVaultState;

  const RecoverBullGoogleDriveState._();
}
