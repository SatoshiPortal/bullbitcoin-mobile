import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/errors.dart';

class PickVaultUsecase {
  final _fileRepository = FileSystemRepository();

  PickVaultUsecase();

  Future<EncryptedVault> execute() async {
    final fileContent = await _fileRepository.pickFile();
    if (!EncryptedVault.isValid(fileContent)) throw InvalidVaultFileError();

    return EncryptedVault(file: fileContent);
  }
}
