import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

class PickVaultUsecase {
  final FileSystemRepository _fileSystemRepository;

  PickVaultUsecase({required this._fileSystemRepository});

  Future<Result<EncryptedVault, RecoverBullCoreFailure>> execute() {
    return _fileSystemRepository.pickVault();
  }
}
