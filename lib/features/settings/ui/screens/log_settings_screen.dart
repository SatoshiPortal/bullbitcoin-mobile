import 'dart:io';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class LogSettingsScreen extends StatelessWidget {
  const LogSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
                tileColor: Colors.transparent,
                title: const Text('Share migration logs'),
                onTap: () => _shareLogs(context),
                trailing: const Icon(Icons.share),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
                tileColor: Colors.transparent,
                title: const Text('Share session logs'),
                onTap: () => _shareSessionLogs(context),
                trailing: const Icon(Icons.share_sharp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareLogs(BuildContext context) async {
    if (!context.mounted) return;
    try {
      if (!context.mounted) return;
      await _shareFile(context, log.migrationLogs);
    } catch (e) {
      if (!context.mounted) return;
      _showErrorSnackbar(context, e.toString());
    }
  }

  Future<void> _shareSessionLogs(BuildContext context) async {
    try {
      await log.dumpSessionToFile();
      if (!context.mounted) return;
      await _shareFile(context, log.sessionLogs);
    } catch (e) {
      if (!context.mounted) return;
      _showErrorSnackbar(context, e.toString());
    }
  }

  Future<void> _shareFile(BuildContext context, File file) async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    if (!await file.exists()) {
      messenger.showSnackBar(
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
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  void _showErrorSnackbar(BuildContext context, String error) {
    _showSnackbar(
      context,
      Text(
        'Error sharing logs: $error',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
    );
  }

  void _showSnackbar(BuildContext context, Widget content) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        duration: const Duration(seconds: 2),
        backgroundColor: theme.colorScheme.onSurface.withAlpha(204),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
