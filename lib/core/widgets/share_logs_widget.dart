import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';

class ShareLogsWidget extends StatelessWidget {
  const ShareLogsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          tileColor: context.appColors.transparent,
          title: Text(context.loc.shareLogsLabel),
          onTap: () => _shareLogs(context),
          trailing: const Icon(Icons.share_sharp),
        ),
        const Gap(8),
        GestureDetector(
          onTap: () => _deleteLogs(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              context.loc.deleteLogsTitle,
              style: TextStyle(
                color: context.appColors.error,
                fontSize: 14,
                decoration: TextDecoration.underline,
                decorationColor: context.appColors.error,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteLogs(BuildContext context) async {
    await log.deleteLogs();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.loc.logsDeletedMessage,
          textAlign: .center,
          style: const TextStyle(fontSize: 14),
        ),
        duration: const Duration(seconds: 2),
        behavior: .floating,
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
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
        context.loc.errorSharingLogsMessage(error),
        textAlign: .center,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  void _showSnackbar(BuildContext context, Widget content) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        duration: const Duration(seconds: 2),
        behavior: .floating,
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
