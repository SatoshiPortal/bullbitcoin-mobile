import 'package:bull_recoverbull/src/domain/entity/drive_file_metadata.dart';
import 'package:bull_recoverbull/src/domain/entity/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_google_drive_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class RecoverBullGoogleDriveState with _$RecoverBullGoogleDriveState {
  const factory RecoverBullGoogleDriveState({
    @Default(false) bool isLoading,
    RecoverBullGoogleDriveFailure? failure,
    @Default([]) List<DriveFileMetadata> driveMetadata,
    @Default(null) EncryptedVault? selectedVault,
  }) = _RecoverBullSelectVaultState;

  const RecoverBullGoogleDriveState._();
}
