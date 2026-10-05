import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BackupReminderSetting extends StatelessWidget {
  const BackupReminderSetting({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<BackupReminderCubit, BackupReminderState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure && current.failure != null,
        listener: (context, state) => SnackBarUtils.showSnackBar(
          context,
          state.failure!.toTranslated(context),
        ),
        builder: (context, state) => Row(
          children: [
            Expanded(child: Text(context.loc.backupReminderDismissForever)),
            BullSwitch(
              value: state.disabled ?? false,
              onChanged: state.saving || state.disabled == null
                  ? null
                  : (disabled) => _setDisabled(context, disabled),
            ),
          ],
        ),
      );

  Future<void> _setDisabled(BuildContext context, bool disabled) async {
    if (disabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.loc.backupReminderDismissForeverConfirmTitle),
          content: Text(context.loc.backupReminderDismissForeverConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.loc.cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.loc.backupReminderDismissForeverConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    await context.read<BackupReminderCubit>().setDisabled(disabled);
  }
}
