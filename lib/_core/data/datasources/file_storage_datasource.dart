import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class FileStorageDatasource {
  final FilePicker _filePicker;

  FileStorageDatasource({FilePicker? filePicker})
      : _filePicker = filePicker ?? FilePicker.platform;

  Future<File> saveToFile(File file, String value) async {
    return await file.writeAsString(value);
  }

  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete(recursive: true);
    }
  }

  Future<String> getAppDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return appDocDir.path;
  }

  Future<String> getDownloadDirectory() async {
    final downloadDir = await getDownloadsDirectory();
    if (downloadDir == null) {
      throw const FileSystemException('Could not get downloads directory');
    }
    return downloadDir.path;
  }

  Future<File?> pickFile() async {
    final files = await _filePicker.pickFiles();
    if (files == null) throw 'No file selected';

    final path = files.files.single.path;
    if (path == null) throw 'No data selected';

    final file = File(path);

    return file;
  }

  Future<String> getDirectoryPath() async {
    final path = await _filePicker.getDirectoryPath();
    if (path == null) throw 'No directory selected';
    return path;
  }
}
