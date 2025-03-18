import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

abstract class FileStorageDataSource {
  Future<File> saveToFile(File file, String value);
  Future<void> deleteFile(String filePath);
  Future<String> getAppDirectory();
  Future<String> getDownloadDirectory();
  Future<File?> pickFile();
}

class FileStorageDataSourceImpl implements FileStorageDataSource {
  final FilePicker _filePicker;

  FileStorageDataSourceImpl({FilePicker? filePicker})
      : _filePicker = filePicker ?? FilePicker.platform;

  @override
  Future<File> saveToFile(File file, String value) async {
    return await file.writeAsString(value);
  }

  @override
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete(recursive: true);
    }
  }

  @override
  Future<String> getAppDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return appDocDir.path;
  }

  @override
  Future<String> getDownloadDirectory() async {
    final downloadDir = await getDownloadsDirectory();
    if (downloadDir == null) {
      throw const FileSystemException('Could not get downloads directory');
    }
    return downloadDir.path;
  }

  @override
  Future<File?> pickFile() async {
    final files = await _filePicker.pickFiles();
    if (files == null) throw 'No file selected';

    final path = files.files.single.path;
    if (path == null) throw 'No data selected';

    final file = File(path);

    return file;
  }
}
