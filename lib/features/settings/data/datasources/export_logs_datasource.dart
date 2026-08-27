import 'dart:convert';

import 'package:file_picker/file_picker.dart';

abstract interface class ExportLogsDatasource {
  Future<bool> export(List<String> lines);
}

class FilePickerLogsDatasource implements ExportLogsDatasource {
  const FilePickerLogsDatasource();

  @override
  Future<bool> export(List<String> lines) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final result = await FilePicker.platform.saveFile(
      bytes: utf8.encode(lines.join('\n')),
      fileName: 'bull_logs_$timestamp.tsv',
    );
    return result != null;
  }
}
