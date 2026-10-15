import '../entities/encrypted_vault.dart';
import '../repositories/file_system_repository.dart';
import '../recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class SaveFileToSystemUsecase {
  final FileSystemRepository _fileSystemRepository;

  SaveFileToSystemUsecase({required this._fileSystemRepository});

  Future<Result<Null, RecoverBullFailure>> execute({
    required EncryptedVault vault,
  }) => _fileSystemRepository.saveVault(vault);
}
