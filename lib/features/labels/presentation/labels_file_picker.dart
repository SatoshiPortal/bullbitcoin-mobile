import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Instance seam over the static `FilePicker` API, so the labels cubit can be tested with a fake.
///
/// file_picker 11 made its methods static and dropped `FilePicker.platform`, which the cubit used to inject.
class LabelsFilePicker {
  const LabelsFilePicker();

  Future<FilePickerResult?> pickFiles({FileType type = FileType.any}) =>
      FilePicker.pickFiles(type: type);

  Future<String?> saveFile({
    required Uint8List bytes,
    required String fileName,
  }) => FilePicker.saveFile(bytes: bytes, fileName: fileName);

  Future<bool?> clearTemporaryFiles() => FilePicker.clearTemporaryFiles();
}
