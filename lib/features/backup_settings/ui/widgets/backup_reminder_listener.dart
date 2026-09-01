import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BackupReminderListener extends StatelessWidget {
  final Widget child;
  final void Function(BackupReminder reminder) onAction;

  const BackupReminderListener({
    super.key,
    required this.child,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BackupReminderCubit, BackupReminderState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) => SnackBarUtils.showSnackBar(
            context,
            state.failure!.toTranslated(context),
          ),
        ),
        BlocListener<BackupReminderCubit, BackupReminderState>(
          listenWhen: (previous, current) =>
              previous.reminder != current.reminder && current.reminder != null,
          listener: (context, state) async {
            final reminder = state.reminder;
            if (reminder == null) return;
            final act = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => PopScope(
                canPop: false,
                child: _BackupReminderDialog(reminder: reminder),
              ),
            );
            if (!context.mounted) return;
            if (act == true) {
              context.read<BackupReminderCubit>().actionOpened();
              onAction(reminder);
            } else {
              await context.read<BackupReminderCubit>().dismissCurrent();
            }
          },
        ),
      ],
      child: child,
    );
  }
}

final class _BackupReminderDialog extends StatelessWidget {
  final BackupReminder reminder;

  const _BackupReminderDialog({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final copy = _copy(context, reminder);
    return AlertDialog(
      title: Text(copy.title),
      content: SingleChildScrollView(
        child: copy.showLossReasons
            ? _NoBackupWarningBody(copy: copy)
            : Text(copy.body),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(copy.secondary),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(copy.primary),
        ),
      ],
    );
  }

  static _ReminderCopy _copy(BuildContext context, BackupReminder reminder) =>
      switch (reminder) {
        BackupReminder.noTestedBackup => _ReminderCopy(
          title: context.loc.backupReminderNoBackupTitle,
          body: context.loc.backupReminderNoBackupBody,
          primary: context.loc.backupReminderBackUpNow,
          secondary: context.loc.backupReminderNotNow,
          showLossReasons: true,
        ),
        BackupReminder.largeBalanceNeedsPhysicalBackup => _ReminderCopy(
          title: context.loc.backupReminderLargeBalanceTitle,
          body: context.loc.backupReminderLargeBalanceBody,
          primary: context.loc.backupReminderAddPhysical,
          secondary: context.loc.backupReminderDismissRisk,
        ),
        BackupReminder.addPhysicalBackup => _ReminderCopy(
          title: context.loc.backupReminderAddPhysicalTitle,
          body: context.loc.backupReminderAddPhysicalBody,
          primary: context.loc.backupReminderAddPhysical,
          secondary: context.loc.backupReminderLater180Days,
        ),
        BackupReminder.testPhysicalBackup => _ReminderCopy(
          title: context.loc.backupReminderTestPhysicalTitle,
          body: context.loc.backupReminderTestPhysicalBody,
          primary: context.loc.backupReminderTestPhysical,
          secondary: context.loc.backupReminderLater365Days,
        ),
        BackupReminder.testEncryptedVault => _ReminderCopy(
          title: context.loc.backupReminderTestVaultTitle,
          body: context.loc.backupReminderTestVaultBody,
          primary: context.loc.backupReminderTestVault,
          secondary: context.loc.backupReminderLater366Days,
        ),
      };
}

final class _ReminderCopy {
  final String title;
  final String body;
  final String primary;
  final String secondary;
  final bool showLossReasons;

  const _ReminderCopy({
    required this.title,
    required this.body,
    required this.primary,
    required this.secondary,
    this.showLossReasons = false,
  });
}

final class _NoBackupWarningBody extends StatelessWidget {
  final _ReminderCopy copy;

  const _NoBackupWarningBody({required this.copy});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(copy.body),
      const SizedBox(height: 8),
      for (final reason in [
        context.loc.backupReminderLoseReasonLostPhone,
        context.loc.backupReminderLoseReasonDeletedApp,
        context.loc.backupReminderLoseReasonCriticalIssue,
        context.loc.backupReminderLoseReasonKeystore,
        context.loc.backupReminderLoseReasonCloudRestore,
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(reason)),
            ],
          ),
        ),
      const SizedBox(height: 8),
      Text(
        context.loc.backupReminderNoRecovery,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
  );
}
