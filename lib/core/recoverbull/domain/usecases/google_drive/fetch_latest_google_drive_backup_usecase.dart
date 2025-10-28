import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';

class FetchLatestGoogleDriveVaultUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchLatestGoogleDriveVaultUsecase({
    required GoogleDriveRepository driveRepository,
  }) : _driveRepository = driveRepository;

  Future<EncryptedVault> execute() async {
    try {
      final availableBackups = await _driveRepository.fetchAllMetadata();
      final latestBackup = availableBackups.reduce((a, b) {
        final aTime = a.createdTime;
        final bTime = b.createdTime;
        return aTime.compareTo(bTime) > 0 ? a : b;
      });
      final content = await _driveRepository.fetchFileContent(latestBackup.id);
      return EncryptedVault(file: content);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
