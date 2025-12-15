import 'dart:convert';
import 'dart:io';
import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:file_picker/file_picker.dart';

class FileStorageDatasource {
  FileStorageDatasource();

  Future<File> pickFile({List<String>? extensions}) async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: extensions,
      type: extensions != null ? FileType.custom : FileType.any,
    );
    if (result != null) return File(result.files.single.path!);

    throw FileStorageException('File not selected');
  }

  Future<void> saveFile(String content, String filename) async {
    final bytes = utf8.encode(content);
    final result = await FilePicker.platform.saveFile(
      bytes: bytes,
      fileName: filename,
    );

    if (result == null) throw FileStorageException('File not saved');
  }
}

class FileStorageException extends BullException {
  FileStorageException(super.message);
}
