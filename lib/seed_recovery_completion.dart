import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/public/backup_settings_facade.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> offerDataBackupAfterPhysicalRestore(
  BuildContext context,
  Map<String, String?> initialWalletLabels,
) async {
  final check = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.loc.dataBackupRestoreCheckTitle),
      content: Text(context.loc.dataBackupRestoreCheckBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.loc.cancelButton),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.loc.dataBackupCheckServer),
        ),
      ],
    ),
  );
  if (check != true || !context.mounted) return;
  await context.pushNamed<void>(
    BackupSettingsRoute.dataRecovery.name,
    extra: DataBackupRecoveryArgs(
      enableAfterRecovery: true,
      initialWalletLabels: initialWalletLabels,
    ),
  );
}
