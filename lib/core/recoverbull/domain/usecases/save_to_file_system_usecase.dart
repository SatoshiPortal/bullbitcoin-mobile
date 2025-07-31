import 'dart:io';

import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class SaveToFileSystemUsecase {
  final FileSystemRepository fileSystemRepository;

  SaveToFileSystemUsecase(this.fileSystemRepository);

  Future<void> execute(String path, String content) async {
    try {
      final now = DateTime.now();
      final formattedDate = now.millisecondsSinceEpoch;
      final backupInfo = content.backupInfo;
      final filename = '${formattedDate}_${backupInfo.id}.json';

      final backupDir = await Directory(path).create(recursive: true);
      final file = File('${backupDir.path}/$filename');

      await fileSystemRepository.saveFile(file, content);
    } catch (e) {
      log.severe('Failed to save file to file system: $e');
      throw Exception("Failed to save file to file system");
    }
  }
}
