import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

class FetchLatestGoogleDriveVaultUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchLatestGoogleDriveVaultUsecase({required this._driveRepository});

  Future<Result<EncryptedVault, RecoverBullCoreFailure>> execute() {
    return _driveRepository.fetchLatestVault();
  }
}
