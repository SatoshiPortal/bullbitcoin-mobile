import '../../domain/entities/drive_file_metadata.dart';
import '../../domain/entities/encrypted_vault.dart';
import '../../domain/recoverbull_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class RecoverBullGoogleDriveState with _$RecoverBullGoogleDriveState {
  const factory RecoverBullGoogleDriveState({
    @Default(false) bool isLoading,
    RecoverBullFailure? failure,
    @Default([]) List<DriveFileMetadata> driveMetadata,
    @Default(null) EncryptedVault? selectedVault,
  }) = _RecoverBullSelectVaultState;

  const RecoverBullGoogleDriveState._();
}
