import 'dart:io';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:path_provider/path_provider.dart';

class FileStorage {
  Future<(File?, Err?)> saveToFile(File file, String value) async {
    try {
      final f = await file.writeAsString(value);
      return (f, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<Err?> deleteFileFromSD(String dbDir) async {
    try {
      final dbFile = File(dbDir);
      if (dbFile.existsSync()) {
        await dbFile.delete(recursive: true);
      }
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(String?, Err?)> getAppDirectory() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      return (appDocDir.path, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(String?, Err?)> getDownloadDirectory() async {
    try {
      final appDocDir = await getDownloadsDirectory();
      if (appDocDir == null) {
        throw 'Could not get downloads directory';
      }
      return (appDocDir.path, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
