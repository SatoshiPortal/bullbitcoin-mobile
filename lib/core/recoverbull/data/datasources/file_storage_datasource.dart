import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FileStorageDatasource {
  FileStorageDatasource();

  Future<File> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) return File(result.files.single.path!);

    throw FileStorageException('No file selected');
  }

  Future<void> saveFile(String content, String filename) async {
    final bytes = utf8.encode(content);
    final result = await FilePicker.platform.saveFile(
      bytes: bytes,
      fileName: filename,
    );

    if (result == null) throw FileStorageException('file not saved');
  }
}

class FileStorageException implements Exception {
  final String message;

  FileStorageException(this.message);

  @override
  String toString() => message;
}
