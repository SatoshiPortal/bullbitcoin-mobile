import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class FileStorageDatasource {
  FileStorageDatasource();

  Future<File> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) return File(result.files.single.path!);

    throw const FileSystemException('No file selected');
  }

  Future<String?> pickDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) return result;

    throw const FileSystemException('No directory selected');
  }

  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
