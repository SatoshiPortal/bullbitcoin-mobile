import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_facade.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BackupSettingsScope extends StatelessWidget {
  final Widget child;

  const BackupSettingsScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<BackupReminderCubit>()..loadPreferences(),
    child: child,
  );
}

class BackupReminderHomeContribution extends StatefulWidget {
  final List<Wallet> wallets;

  const BackupReminderHomeContribution({super.key, required this.wallets});

  @override
  State<BackupReminderHomeContribution> createState() =>
      _BackupReminderHomeState();
}

class _BackupReminderHomeState extends State<BackupReminderHomeContribution> {
  bool _scheduled = false;
  bool _dialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.isCurrentOf(context) ?? false) _scheduleCheck();
  }

  @override
  void didUpdateWidget(BackupReminderHomeContribution oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.wallets, widget.wallets)) _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduled = false;
      if (!mounted || !(ModalRoute.isCurrentOf(context) ?? false)) return;
      await context.read<BackupReminderCubit>().evaluate(widget.wallets);
      if (mounted) await _showReminder();
    });
  }

  Future<void> _showReminder() async {
    if (_dialogOpen || !(ModalRoute.isCurrentOf(context) ?? false)) return;
    final cubit = context.read<BackupReminderCubit>();
    final reminder = cubit.state.reminder;
    if (reminder == null || !cubit.claimReminder(reminder)) return;
    _dialogOpen = true;
    final act = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: PopScope(
          canPop: false,
          child: _ReminderDialog(reminder: reminder),
        ),
      ),
    );
    _dialogOpen = false;
    if (act != true || !mounted) return;
    switch (reminder) {
      case BackupReminder.largeBalanceNeedsPhysicalBackup ||
          BackupReminder.addPhysicalBackup:
        await context.pushNamed<void>(
          TestWalletBackupFacade.routeName,
          extra: TestPhysicalBackupFlow.backup,
        );
      case BackupReminder.testPhysicalBackup:
        await context.pushNamed<void>(
          TestWalletBackupFacade.routeName,
          extra: TestPhysicalBackupFlow.verify,
        );
      case BackupReminder.testEncryptedVault:
        await RecoverBullFacade.openTest(context);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<BackupReminderCubit, BackupReminderState>(
        listener: (context, state) {
          if (state.reminder != null) _showReminder();
          if (state.failure != null &&
              !_dialogOpen &&
              (ModalRoute.isCurrentOf(context) ?? false)) {
            SnackBarUtils.showSnackBar(
              context,
              state.failure!.toTranslated(context),
            );
          }
        },
        child: const SizedBox.shrink(),
      );
}

class _ReminderDialog extends StatelessWidget {
  final BackupReminder reminder;

  const _ReminderDialog({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final (title, body, primary, secondary) = switch (reminder) {
      BackupReminder.largeBalanceNeedsPhysicalBackup => (
        loc.backupReminderLargeBalanceTitle,
        loc.backupReminderLargeBalanceBody,
        loc.backupReminderAddPhysical,
        loc.backupReminderDismissRisk,
      ),
      BackupReminder.addPhysicalBackup => (
        loc.backupReminderAddPhysicalTitle,
        loc.backupReminderAddPhysicalBody,
        loc.backupReminderAddPhysical,
        loc.backupReminderLater180Days,
      ),
      BackupReminder.testPhysicalBackup => (
        loc.backupReminderTestPhysicalTitle,
        loc.backupReminderTestPhysicalBody,
        loc.backupReminderTestPhysical,
        loc.backupReminderLater365Days,
      ),
      BackupReminder.testEncryptedVault => (
        loc.backupReminderTestVaultTitle,
        loc.backupReminderTestVaultBody,
        loc.backupReminderTestVault,
        loc.backupReminderLater366Days,
      ),
    };
    return BlocBuilder<BackupReminderCubit, BackupReminderState>(
      builder: (context, state) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              if (state.failure != null)
                Text(state.failure!.toTranslated(context)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: state.saving
                ? null
                : () async {
                    final saved = await context
                        .read<BackupReminderCubit>()
                        .dismiss(reminder);
                    if (saved && context.mounted) Navigator.pop(context, false);
                  },
            child: Text(secondary),
          ),
          FilledButton(
            onPressed: state.saving ? null : () => Navigator.pop(context, true),
            child: Text(primary),
          ),
        ],
      ),
    );
  }
}
