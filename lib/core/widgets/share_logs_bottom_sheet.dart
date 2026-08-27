import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> showLogsShareSheet({
  required BuildContext context,
  required VoidCallback onShare,
  required VoidCallback onExport,
}) async {
  await BullBottomSheet.show(
    context: context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onShare();
            },
            icon: const Icon(Icons.share_sharp),
            label: Text(
              context.loc.logsShareOptionShare,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const Divider(),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onExport();
            },
            icon: const Icon(Icons.file_download_outlined),
            label: Text(
              context.loc.logsShareOptionExport,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    ),
  );
}

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
