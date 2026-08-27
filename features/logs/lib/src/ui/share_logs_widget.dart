import 'package:bull_logs/public/logs_facade.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_logs/generated/l10n/logs_localizations.dart';

class ShareLogsWidget extends StatelessWidget {
  const ShareLogsWidget({super.key, required this.facade});

  final LogsFacade facade;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      BullSettingsEntryItem(
        icon: Icons.share_sharp,
        title: LogsLocalizations.of(context).logsShareOptionShare,
        onTap: () => _share(context),
      ),
      const Gap(8),
      BullSettingsEntryItem(
        icon: Icons.file_download_outlined,
        title: LogsLocalizations.of(context).logsShareOptionExport,
        onTap: () => _export(context),
      ),
    ],
  );

  Future<void> _share(BuildContext context) async {
    try {
      final result = await facade.shareAll();
      if (result case Err()) throw StateError('share failed');
    } catch (_) {
      if (context.mounted) {
        BullSnackBar.show(
          context,
          message: LogsLocalizations.of(context).logsShareFailedMessage,
        );
      }
    }
  }

  Future<void> _export(BuildContext context) async {
    try {
      final result = await facade.exportAll();
      if (result case Ok(value: false)) return;
      if (result case Err()) throw StateError('export failed');
      if (context.mounted) {
        BullSnackBar.show(
          context,
          message: LogsLocalizations.of(context).logsExportedMessage,
        );
      }
    } catch (_) {
      if (context.mounted) {
        BullSnackBar.show(
          context,
          message: LogsLocalizations.of(context).logsExportFailedMessage,
        );
      }
    }
  }
}
