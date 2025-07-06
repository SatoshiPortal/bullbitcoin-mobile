import 'dart:io';

class LocalDatasource {
  final Directory _directory;
  static const String _defaultFileName = 'something.txt';

  LocalDatasource({required Directory directory}) : _directory = directory;

  File get _file => File('${_directory.path}/$_defaultFileName');

  Future<File> writeToFile(String data) async {
    try {
      await _file.writeAsString(data);
      return _file;
    } catch (e) {
      throw 'Failed to write file: $e';
    }
  }

  Future<File?> readFile() async {
    try {
      if (_file.existsSync()) return _file;
      return null;
    } catch (e) {
      throw 'Failed to read file: $e';
    }
  }
}
