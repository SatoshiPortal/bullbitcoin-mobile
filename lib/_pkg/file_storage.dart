import 'dart:io';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
      final PermissionStatus permissionStatus = await Permission.storage.request();
      if (permissionStatus.isGranted) {
        // Pick a directory using the file_picker package
        final Directory directory = await FilePicker.platform.getDirectoryPath().then(
              (path) => Directory(path!),
            );
        // // final dir = await getTemporaryDirectory();
        // final Uint8List data = Uint8List.fromList(utf8.encode(psbt));
        final file = File('$txid.psbt');
        await file.writeAsString(psbt);

        // final params = SaveFileDialogParams(
        //   fileName: '$txid.psbt',
        //   data: data,
        // );
        // final finalPath = await FlutterFileDialog.saveFile(params: params);

        // if (finalPath == null) throw 'Could not save file';
        return null;
      } else {
        return Err(permissionStatus.toString());
      }
    } catch (e) {
      return Err(e.toString());
    }
  }
}
