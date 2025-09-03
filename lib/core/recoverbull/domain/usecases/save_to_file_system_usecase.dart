import 'dart:io';

import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class SaveToFileSystemUsecase {
  final FileSystemRepository fileSystemRepository;

  SaveToFileSystemUsecase(this.fileSystemRepository);

  Future<void> execute(String path, String content) async {
    try {
      final vault = EncryptedVault(file: content);
      final filename = vault.filename;

      final vaultDir = await Directory(path).create(recursive: true);
      final file = File('${vaultDir.path}/$filename');

      await fileSystemRepository.saveFile(file, content);
    } catch (e) {
      log.severe('Failed to save file to file system: $e');
      throw Exception("Failed to save file to file system");
    }
  }
}
