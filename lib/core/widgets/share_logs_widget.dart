import 'dart:io';

import 'package:bb_mobile/core/screens/logs_viewer_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';

class ShareLogsWidget extends StatefulWidget {
  final bool migrationLogs;
  final bool sessionLogs;

  const ShareLogsWidget({
    super.key,
    this.migrationLogs = true,
    this.sessionLogs = true,
  });

  @override
  State<ShareLogsWidget> createState() => _ShareLogsWidgetState();
}

class _ShareLogsWidgetState extends State<ShareLogsWidget> {
  bool _showLogsInline = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.sessionLogs)
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
        if (widget.migrationLogs)
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
          onTap: () {
            final navigator = Navigator.maybeOf(context);
            if (navigator != null) {
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => const LogsViewerScreen(),
                ),
              );
            } else {
              setState(() {
                _showLogsInline = !_showLogsInline;
              });
            }
          },
          trailing: Icon(_showLogsInline ? Icons.expand_less : Icons.list_alt),
        ),
        if (_showLogsInline) ...[
          const Gap(16),
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Session Logs', style: context.font.titleMedium),
                      Text(
                        '${log.session.length} entries',
                        style: context.font.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    padding: const EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(log.session.length, (index) {
                          final logLine = log.session[index];
                          return Row(
                            children: [
                              IconButton(
                                onPressed:
                                    () => Clipboard.setData(
                                      ClipboardData(text: logLine),
                                    ),
                                icon: const Icon(Icons.copy, size: 14),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                              SelectableText(
                                logLine.replaceAll('\t', ' | '),
                                style: context.font.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: context.colour.onSurface,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
