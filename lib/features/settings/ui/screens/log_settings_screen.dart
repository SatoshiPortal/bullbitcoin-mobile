import 'dart:io';

import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LogSettingsScreen extends StatelessWidget {
  const LogSettingsScreen({super.key});

  Future<void> _shareLogs(BuildContext context) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logFile = File(
        '${dir.path}/${SettingsConstants.logFileName}',
      ); // Adjust to your filename

      if (!await logFile.exists()) {
        // ignore: use_build_context_synchronously
        final theme = Theme.of(context);
        ScaffoldMessenger.of(
          // ignore: use_build_context_synchronously
          context,
        ).showSnackBar(
          SnackBar(
            content: const Text(
              'No log file found.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: theme.colorScheme.onSurface.withAlpha(204),
            behavior: SnackBarBehavior.floating,
            elevation: 4,
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
        return;
      }

      await SharePlus.instance.share(ShareParams(files: [XFile(logFile.path)]));
    } catch (e) {
      // ignore: use_build_context_synchronously
      final theme = Theme.of(context);
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Error sharing logs: $e',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: theme.colorScheme.onSurface.withAlpha(204),
          behavior: SnackBarBehavior.floating,
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text('Download / share logs'),
              onTap: () async {
                await _shareLogs(context);
              },
              trailing: const Icon(Icons.share),
            ),
          ],
        ),
      ),
    );
  }
}
