import '../../../data/google_drive_repository.dart';
import '../../entities/encrypted_vault.dart';
import '../../recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class FetchLatestGoogleDriveVaultUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchLatestGoogleDriveVaultUsecase({required this._driveRepository});

  Future<Result<EncryptedVault, RecoverBullFailure>> execute() {
    return _driveRepository.fetchLatestVault();
  }
}
