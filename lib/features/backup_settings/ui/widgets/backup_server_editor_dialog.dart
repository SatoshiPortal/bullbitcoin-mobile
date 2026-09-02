import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_server_config.dart';
import 'package:flutter/material.dart';

Future<String?> showBackupServerEditorDialog(
  BuildContext context, {
  String? current,
}) => showDialog<String>(
  context: context,
  builder: (_) => BackupServerEditorDialog(
    initialValue: current ?? walletBackupDefaultServerUrl,
  ),
);

class BackupServerEditorDialog extends StatefulWidget {
  final String initialValue;

  const BackupServerEditorDialog({required this.initialValue, super.key});

  @override
  State<BackupServerEditorDialog> createState() =>
      _BackupServerEditorDialogState();
}

class _BackupServerEditorDialogState extends State<BackupServerEditorDialog> {
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
      children: [
        Text(context.loc.walletBackupSettingsServerChangeWarning),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: widget.initialValue,
          autocorrect: false,
          keyboardType: TextInputType.url,
          onChanged: _changed,
          decoration: InputDecoration(
            labelText: context.loc.walletBackupSettingsServerUrl,
            helperText: _error == null
                ? context.loc.walletBackupSettingsServerHelp
                : null,
            errorText: _error,
          ),
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
