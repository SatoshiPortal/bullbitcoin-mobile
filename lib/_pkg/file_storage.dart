import 'dart:io';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
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

  Future<Err?> deleteFile(String dbDir) async {
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

  // Future<Err?> selectAndSaveFile({
  //   required String txt,
  //   required String fileName,
  //   required String mime,
  // }) async {
  //   try {
  //     final textBytes = Uint8List.fromList(txt.codeUnits);
  //     await DocumentFileSavePlus().saveFile(textBytes, fileName, mime);
  //     return null;
  //   } catch (e) {
  //     return Err(e.toString());
  //   }
  // }

  Future<Err?> savePSBT({
    required String psbt,
    required String txid,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$txid.psbt');
      await file.writeAsString(psbt);

      final params = SaveFileDialogParams(sourceFilePath: file.path);
      final finalPath = await FlutterFileDialog.saveFile(params: params);

      if (finalPath == null) throw 'Could not save file';
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}
