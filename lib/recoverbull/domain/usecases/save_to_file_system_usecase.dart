import 'dart:io';

import 'package:bb_mobile/_core/domain/repositories/file_system_repository.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class SaveToFileSystemUsecase {
  final FileSystemRepository fileSystemRepository;

  SaveToFileSystemUsecase(this.fileSystemRepository);

  Future<void> execute(String path, String content) async {
    try {
      final file = File(path);
      await fileSystemRepository.saveFile(file, content);
    } catch (e) {
      debugPrint('Failed to save file to file system: $e');
      throw Exception("Failed to save file to file system");
    }
  }
}
