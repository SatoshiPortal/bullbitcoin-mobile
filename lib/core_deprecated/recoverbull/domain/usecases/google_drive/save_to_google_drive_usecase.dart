import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/entity/encrypted_vault.dart';

class SaveVaultToGoogleDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  SaveVaultToGoogleDriveUsecase({
    required GoogleDriveRepository driveRepository,
  }) : _driveRepository = driveRepository;

  Future<void> execute(EncryptedVault vault) async {
    try {
      await _driveRepository.store(vault.toFile());
    } catch (e) {
      rethrow;
    }
  }
}
