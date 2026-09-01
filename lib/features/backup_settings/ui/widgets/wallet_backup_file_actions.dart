import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter/material.dart';

final class WalletBackupFileActions extends StatelessWidget {
  final bool busy;
  final Future<void> Function(
    WalletBackupFileProtection protection,
    bool confirmedUnencrypted,
  )
  onExport;
  final Future<void> Function() onImport;

  const WalletBackupFileActions({
    super.key,
    required this.busy,
    required this.onExport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SettingsEntryItem(
        icon: Icons.lock_outline,
        title: context.loc.walletBackupFileExportEncrypted,
        onTap: busy
            ? null
            : () => onExport(WalletBackupFileProtection.encrypted, false),
      ),
      SettingsEntryItem(
        icon: Icons.no_encryption_outlined,
        title: context.loc.walletBackupFileExportUnencrypted,
        onTap: busy ? null : () => _exportUnencrypted(context),
      ),
      SettingsEntryItem(
        icon: Icons.file_download_outlined,
        title: context.loc.walletBackupFileImportAction,
        onTap: busy ? null : () => _import(context),
      ),
    ],
  );

  Future<void> _exportUnencrypted(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(dialogContext.loc.walletBackupFileUnencryptedWarning),
            content: Text(
              dialogContext.loc.walletBackupFileUnencryptedConfirmation,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogContext.loc.walletBackupSettingsCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(dialogContext.loc.walletBackupFileContinue),
              ),
            ],
          ),
        ) ==
        true;
    if (confirmed && context.mounted) {
      await onExport(WalletBackupFileProtection.unencrypted, true);
    }
  }

  Future<void> _import(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.walletBackupFileImportTitle),
        content: Text(dialogContext.loc.walletBackupFileImportExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.loc.walletBackupSettingsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.loc.walletBackupFileChoose),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) await onImport();
  }
}
