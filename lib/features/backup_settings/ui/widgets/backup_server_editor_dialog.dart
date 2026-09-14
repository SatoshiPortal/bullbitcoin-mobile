import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_server_config.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText, Gap;
import 'package:flutter/material.dart';

Future<String?> showBackupServerEditorDialog(
  BuildContext context, {
  String? current,
}) => showDialog<String>(
  context: context,
  builder: (_) => _BackupServerEditorDialog(
    initialValue: current ?? walletBackupDefaultServerUrl,
  ),
);

final class _BackupServerEditorDialog extends StatefulWidget {
  final String initialValue;

  const _BackupServerEditorDialog({required this.initialValue});

  @override
  State<_BackupServerEditorDialog> createState() =>
      _BackupServerEditorDialogState();
}

final class _BackupServerEditorDialogState
    extends State<_BackupServerEditorDialog> {
  late String _value = widget.initialValue;
  String? _error;

  void _changed(String value) {
    final error = parseWalletBackupServerOrigin(value) == null
        ? context.loc.walletBackupSettingsServerHelp
        : null;
    setState(() {
      _value = value;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.loc.walletBackupSettingsServer),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.loc.walletBackupSettingsServerChangeWarning),
        const Gap(16),
        BullInputText(
          value: _value,
          onChanged: _changed,
          label: context.loc.walletBackupSettingsServerUrl,
          hint: context.loc.walletBackupSettingsServerHelp,
          errorText: _error,
          autocorrect: false,
          maxLines: 1,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.loc.walletBackupSettingsCancel),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, ''),
        child: Text(context.loc.walletBackupSettingsServerReset),
      ),
      TextButton(
        onPressed: _error == null
            ? () => Navigator.pop(context, _value.trim())
            : null,
        child: Text(context.loc.walletBackupSettingsServerSave),
      ),
    ],
  );
}
