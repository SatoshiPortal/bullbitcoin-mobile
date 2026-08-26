import 'package:bull_recoverbull/src/data/repository/file_system_repository.dart';
import 'package:bull_recoverbull/src/domain/entity/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class PickVaultUsecase {
  final FileSystemRepository _fileSystemRepository;

  PickVaultUsecase({required this._fileSystemRepository});

  Future<Result<EncryptedVault, RecoverBullCoreFailure>> execute() {
    return _fileSystemRepository.pickVault();
  }
}
