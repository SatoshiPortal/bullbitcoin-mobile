import 'dart:io';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:file_picker/file_picker.dart';

class FilePick {
  Future<(File?, Err?)> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) throw 'No file selected';

      final path = result.files.first.path;
      if (path == null) throw 'No data selected';

      final file = File(path);

      return (file, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(String?, Err?)> getDirectoryPath() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) return (null, Err('No directory selected'));
      return (path, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
