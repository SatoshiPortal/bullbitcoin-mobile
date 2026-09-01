import '../../../data/google_drive_repository.dart';
import '../../entities/encrypted_vault.dart';
import '../../recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class SaveVaultToGoogleDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  SaveVaultToGoogleDriveUsecase({required this._driveRepository});

  Future<Result<Null, RecoverBullFailure>> execute(EncryptedVault vault) {
    return _driveRepository.store(vault.toFile());
  }
}
