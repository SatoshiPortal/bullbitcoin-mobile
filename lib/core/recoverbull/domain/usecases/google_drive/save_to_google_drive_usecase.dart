import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

class SaveVaultToGoogleDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  SaveVaultToGoogleDriveUsecase({required this._driveRepository});

  Future<Result<Null, RecoverBullCoreFailure>> execute(EncryptedVault vault) {
    return _driveRepository.store(vault.toFile());
  }
}
