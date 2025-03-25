import 'dart:io';

import 'package:bb_mobile/_core/domain/repositories/file_system_repository.dart';
import 'package:bb_mobile/recover_wallet/domain/entities/backup_info.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class SaveToFileSystemUsecase {
  final FileSystemRepository fileSystemRepository;

  SaveToFileSystemUsecase(this.fileSystemRepository);

  Future<void> execute(String path, String content) async {
    try {
      final now = DateTime.now();
      final formattedDate = now.millisecondsSinceEpoch;
      final backupInfo = BackupInfo(encrypted: content);
      final filename = '${formattedDate}_${backupInfo.id}.json';

      final backupDir = await Directory(path).create(recursive: true);
      final file = File('${backupDir.path}/$filename');

      await fileSystemRepository.saveFile(file, content);
    } catch (e) {
      debugPrint('Failed to save file to file system: $e');
      throw Exception("Failed to save file to file system");
    }
  }
}
