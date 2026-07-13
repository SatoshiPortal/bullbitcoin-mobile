import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/share_logs_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

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
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          tileColor: context.appColors.transparent,
          title: Text(context.loc.logsShareOptionExport),
          onTap: () => _exportLogs(context),
          trailing: const Icon(Icons.file_download_outlined),
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
    SnackBarUtils.showSnackBar(context, context.loc.logsDeletedMessage);
  }

  Future<void> _shareLogs(BuildContext context) async {
    try {
      final logs = await log.readLogs();
      await shareLogsAsFile(logs);
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        context.loc.errorSharingLogsMessage(e.toString()),
      );
    }
  }

  Future<void> _exportLogs(BuildContext context) async {
    try {
      final logs = await log.readLogs();
      final saved = await exportLogsAsFile(logs);
      if (!context.mounted) return;
      if (saved) {
        SnackBarUtils.showSnackBar(context, context.loc.logsExportedMessage);
      }
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showSnackBar(context, context.loc.logsExportFailedMessage);
    }
  }
}
