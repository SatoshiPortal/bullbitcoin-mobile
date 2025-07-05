import 'dart:io';

class LocalDatasource {
  final Directory _directory;

  LocalDatasource({required Directory directory}) : _directory = directory;

  Future<File> writeToFile(String data) async {
    try {
      final file = File('${_directory.path}/example_data.txt');
      await file.writeAsString(data);
      return file;
    } catch (e) {
      throw 'Failed to write file: $e';
    }
  }

  Future<String> readFromFile() async {
    try {
      final file = File('${_directory.path}/example_data.txt');
      return await file.readAsString();
    } catch (e) {
      throw 'Failed to read file: $e';
    }
  }
}
