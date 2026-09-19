import 'dart:async';
import 'package:bb_mobile/features/backup_settings/domain/usecases/update_data_backup_lifecycle_usecase.dart';
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

class BackupSettingsScope extends StatefulWidget {
  final Widget child;
  final bool ready;
  const BackupSettingsScope({
    super.key,
    required this.child,
    required this.ready,
  });

  @override
  State<BackupSettingsScope> createState() => _BackupSettingsScopeState();
}

class _BackupSettingsScopeState extends State<BackupSettingsScope> {
  late final UpdateDataBackupLifecycleUsecase _lifecycle;
  late final AppLifecycleListener _listener;
  late final StreamSubscription<void> _changes;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = locator<UpdateDataBackupLifecycleUsecase>();
    final current = WidgetsBinding.instance.lifecycleState;
    _foreground = current == null || current == AppLifecycleState.resumed;
    _listener = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
        _update();
      },
    );
    _changes = _lifecycle.changes.listen(
      (_) => _update(),
      onError: (Object _) {
        unawaited(_lifecycle.execute(ready: false, foreground: _foreground));
      },
    );
    _update();
  }

  void _update() => unawaited(
    _lifecycle.execute(ready: widget.ready, foreground: _foreground),
  );

  @override
  void didUpdateWidget(BackupSettingsScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready != widget.ready) _update();
  }

  @override
  void dispose() {
    _listener.dispose();
    unawaited(_changes.cancel());
    unawaited(_lifecycle.execute(ready: false, foreground: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<BackupReminderCubit>()..loadPreferences(),
    child: widget.child,
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
