import 'package:bull_logs/generated/l10n/logs_localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

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
          BullSettingsEntryItem(
            icon: Icons.share_sharp,
            title: LogsLocalizations.of(context).logsShareOptionShare,
            onTap: () {
              Navigator.of(context).pop();
              onShare();
            },
          ),
          BullSettingsEntryItem(
            icon: Icons.file_download_outlined,
            title: LogsLocalizations.of(context).logsShareOptionExport,
            onTap: () {
              Navigator.of(context).pop();
              onExport();
            },
          ),
        ],
      ),
    ),
  );
}
