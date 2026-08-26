import 'package:bull_recoverbull/src/data/repository/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/entity/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class FetchLatestGoogleDriveVaultUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchLatestGoogleDriveVaultUsecase({required this._driveRepository});

  Future<Result<EncryptedVault, RecoverBullCoreFailure>> execute() {
    return _driveRepository.fetchLatestVault();
  }
}
