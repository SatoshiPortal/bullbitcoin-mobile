import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'logger.dart';

/// Returns the selected lines with one fresh diagnostic context line first.
Future<List<String>> createLogBundleLines(List<String> lines) async {
  return log.createLogBundleLines(lines);
}

/// Reads all persisted lines and prepends one fresh diagnostic context line.
Future<List<String>> readLogsForSharing() async =>
    createLogBundleLines(await log.readLogs());

Future<void> shareLogsAsText(List<String> logs) async {
  await SharePlus.instance.share(
    ShareParams(
      text: logs.join('\n'),
      subject: 'bull_logs.tsv',
      title: 'bull_logs.tsv',
    ),
  );
}

Future<void> shareLogsAsFile(List<String> logs) async {
  final path = p.join(
    (await getTemporaryDirectory()).path,
    _timestampedLogFileName(),
  );
  await File(path).writeAsString(logs.join('\n'));
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], subject: 'bull_logs.tsv'),
  );
}

/// Returns true if the file was saved, false if the user cancelled.
Future<bool> exportLogsAsFile(List<String> logs) async {
  final result = await FilePicker.platform.saveFile(
    bytes: utf8.encode(logs.join('\n')),
    fileName: _timestampedLogFileName(),
  );
  return result != null;
}

String _timestampedLogFileName() {
  final timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  return 'bull_logs_$timestamp.tsv';
}
