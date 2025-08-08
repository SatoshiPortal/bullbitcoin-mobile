import 'dart:io';

import 'package:bb_mobile/core/screens/logs_viewer_screen.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';

class ShareLogsWidget extends StatelessWidget {
  final bool migrationLogs;
  final bool sessionLogs;

  const ShareLogsWidget({
    super.key,
    this.migrationLogs = true,
    this.sessionLogs = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (sessionLogs)
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
            tileColor: Colors.transparent,
            title: const Text('Share session logs'),
            onTap: () => _shareSessionLogs(context),
            trailing: const Icon(Icons.share_sharp),
          ),
        const Gap(16),
        if (migrationLogs)
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
            tileColor: Colors.transparent,
            title: const Text('Share migration logs'),
            onTap: () => _shareLegacyMigrationLogs(context),
            trailing: const Icon(Icons.share),
          ),
        const Gap(16),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          tileColor: Colors.transparent,
          title: const Text('View session logs'),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogsViewerScreen(),
                ),
              ),
          trailing: const Icon(Icons.list_alt),
        ),
      ],
    );
  }

  Future<void> _shareLegacyMigrationLogs(BuildContext context) async {
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
