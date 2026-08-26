import 'package:bull_recoverbull/src/data/repository/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/entity/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class SaveVaultToGoogleDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  SaveVaultToGoogleDriveUsecase({required this._driveRepository});

  Future<Result<Null, RecoverBullCoreFailure>> execute(EncryptedVault vault) {
    return _driveRepository.store(vault.toFile());
  }
}
