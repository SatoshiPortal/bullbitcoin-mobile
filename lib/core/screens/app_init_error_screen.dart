import 'package:bb_mobile/core/screens/pre_init_scaffold.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/share_logs_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppInitErrorScreen extends StatelessWidget {
  const AppInitErrorScreen({super.key, required this.error});

  final Object error;

  Future<void> _shareLogs(BuildContext context, AppLocalizations loc) async {
    try {
      final logs = await log.readLogs();
      await shareLogsAsFile(logs);
    } catch (e) {
      log.severe(
        message: 'Failed to share logs',
        error: e,
        trace: StackTrace.current,
      );
      if (!context.mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        loc.errorSharingLogsMessage(e.toString()),
      );
    }
  }

  Future<void> _exportLogs(BuildContext context, AppLocalizations loc) async {
    try {
      final logs = await log.readLogs();
      final saved = await exportLogsAsFile(logs);
      if (!context.mounted) return;
      if (saved) {
        SnackBarUtils.showSnackBar(context, loc.logsExportedMessage);
      }
    } catch (e) {
      log.severe(
        message: 'Failed to export logs',
        error: e,
        trace: StackTrace.current,
      );
      if (!context.mounted) return;
      SnackBarUtils.showSnackBar(context, loc.logsExportFailedMessage);
    }
  }

  Future<void> _contactSupport() async {
    await launchUrl(
      Uri.parse(SettingsConstants.webSupportLink),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _deleteLogs(BuildContext context, AppLocalizations loc) async {
    await log.deleteLogs();
    if (!context.mounted) return;
    SnackBarUtils.showSnackBar(context, loc.logsDeletedMessage);
  }

  @override
  Widget build(BuildContext context) {
    return PreInitScaffold(
      title: (loc) => loc.appInitErrorTitle,
      builder: (context, loc) => [
        PreInitIllustration(
          asset: 'assets/misc/undraw_secure-usb-drive.svg',
          title: loc.appInitErrorHasBackupTitle,
          message: loc.appInitErrorHasBackupMessage,
        ),
        const Gap(32),
        Divider(color: context.appColors.border),
        const Gap(32),
        PreInitIllustration(
          asset: 'assets/misc/undraw_forgot-password.svg',
          title: loc.appInitErrorNoBackupTitle,
          message: loc.appInitErrorNoBackupMessage,
        ),
        const Gap(32),
        BBButton.big(
          label: loc.appInitErrorContactSupportButton,
          iconData: Icons.open_in_new,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
          onPressed: _contactSupport,
        ),
        const Gap(12),
        BBButton.big(
          label: loc.appInitErrorShareLogsButton,
          iconData: Icons.share,
          iconFirst: true,
          bgColor: context.appColors.surface,
          textColor: context.appColors.text,
          borderColor: context.appColors.border,
          outlined: true,
          onPressed: () => _shareLogs(context, loc),
        ),
        const Gap(12),
        BBButton.big(
          label: loc.logsShareOptionExport,
          iconData: Icons.file_download_outlined,
          iconFirst: true,
          bgColor: context.appColors.surface,
          textColor: context.appColors.text,
          borderColor: context.appColors.border,
          outlined: true,
          onPressed: () => _exportLogs(context, loc),
        ),
        const Gap(12),
        BBButton.big(
          label: loc.deleteLogsTitle,
          iconData: Icons.delete_outline,
          iconFirst: true,
          bgColor: context.appColors.surface,
          textColor: context.appColors.error,
          borderColor: context.appColors.error,
          outlined: true,
          onPressed: () => _deleteLogs(context, loc),
        ),
        const Gap(16),
        ErrorDetailsPanel(error: error, label: loc.appInitErrorDetailsToggle),
      ],
    );
  }
}

/// Collapsible raw-error panel. Developer detail, shown only when the user
/// opens it; the screens themselves lead with a localized message.
class ErrorDetailsPanel extends StatefulWidget {
  const ErrorDetailsPanel({
    super.key,
    required this.error,
    required this.label,
  });

  final Object error;
  final String label;

  @override
  State<ErrorDetailsPanel> createState() => _ErrorDetailsPanelState();
}

class _ErrorDetailsPanelState extends State<ErrorDetailsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BBButton.big(
          label: widget.label,
          iconData: _expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          iconFirst: true,
          outlined: true,
          bgColor: context.appColors.surface,
          textColor: context.appColors.text,
          borderColor: context.appColors.border,
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.appColors.border),
            ),
            child: SelectableText(
              widget.error.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
