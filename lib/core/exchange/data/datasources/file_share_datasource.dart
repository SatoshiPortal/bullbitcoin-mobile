import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileShareDatasource {
  Future<void> shareFile({
    required Uint8List fileData,
    required String fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(fileData);

    final xFile = XFile(tempFile.path);
    await SharePlus.instance.share(
      ShareParams(files: [xFile], subject: fileName),
    );
  }
}

