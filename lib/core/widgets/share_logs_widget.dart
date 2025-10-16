import 'package:bb_mobile/core/screens/logs_viewer_screen.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';

class ShareLogsWidget extends StatefulWidget {
  const ShareLogsWidget({super.key});

  @override
  State<ShareLogsWidget> createState() => _ShareLogsWidgetState();
}

class _ShareLogsWidgetState extends State<ShareLogsWidget> {
  bool _showLogsInline = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          tileColor: Colors.transparent,
          title: const Text('Share logs'),
          onTap: () => _shareLogs(context),
          trailing: const Icon(Icons.share_sharp),
        ),
        const Gap(16),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          tileColor: Colors.transparent,
          title: const Text('View logs'),
          onTap: () async {
            final logs = await log.readLogs();
            if (!context.mounted) return;
            final navigator = Navigator.maybeOf(context);
            if (navigator != null) {
              await navigator.push(
                MaterialPageRoute(
                  builder: (context) => LogsViewerScreen(logs: logs),
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
      ],
    );
  }

  Future<void> _shareLogs(BuildContext context) async {
    try {
      final logs = await log.readLogs();
      if (!context.mounted) return;
      await _shareTextLogs(context, logs.join('\n'));
    } catch (e) {
      if (!context.mounted) return;
      _showErrorSnackbar(context, e.toString());
    }
  }

  Future<void> _shareTextLogs(BuildContext context, String text) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'bull_logs.tsv', title: 'bull_logs.tsv'),
    );
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
