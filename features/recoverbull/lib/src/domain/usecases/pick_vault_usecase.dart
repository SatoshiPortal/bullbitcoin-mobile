import '../../data/file_system_repository.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class PickVaultUsecase {
  final FileSystemRepository _fileSystemRepository;

  PickVaultUsecase({required this._fileSystemRepository});

  Future<Result<EncryptedVault, RecoverBullFailure>> execute() {
    return _fileSystemRepository.pickVault();
  }
}
