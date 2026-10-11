import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BackupReminderScope extends StatelessWidget {
  final Widget child;

  const BackupReminderScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<BackupReminderCubit>()..loadPreferences(),
    child: child,
  );
}

class BackupReminderHomeContribution extends StatefulWidget {
  final List<Wallet> wallets;
  final String homePath;

  const BackupReminderHomeContribution({
    super.key,
    required this.wallets,
    required this.homePath,
  });

  @override
  State<BackupReminderHomeContribution> createState() =>
      _BackupReminderHomeState();
}

class _BackupReminderHomeState extends State<BackupReminderHomeContribution> {
  bool _scheduled = false;
  bool _dialogOpen = false;
  GoRouter? _router;

  bool get _isVisible => _router?.state.uri.path == widget.homePath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      router.routerDelegate.addListener(_onRouteChanged);
    }
    _onRouteChanged();
  }

  void _onRouteChanged() {
    if (_isVisible) _scheduleCheck();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
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
      if (!mounted || !_isVisible) return;
      await context.read<BackupReminderCubit>().evaluate(widget.wallets);
      if (mounted) await _showReminder();
    });
  }

  Future<void> _showReminder() async {
    if (_dialogOpen || !_isVisible) return;
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
        await locator<RecoverBullFeature>().open<void>(
          context,
          RecoverBullFlow.testVault,
        );
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<BackupReminderCubit, BackupReminderState>(
        listener: (context, state) {
          if (state.reminder != null) _showReminder();
          if (state.failure case final failure?
              when !_dialogOpen && _isVisible) {
            SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
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
      builder: (context, state) => Center(
        child: SingleChildScrollView(
          child: AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body),
                if (state.failure case final failure?)
                  Text(failure.toTranslated(context)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: state.saving
                    ? null
                    : () async {
                        final saved = await context
                            .read<BackupReminderCubit>()
                            .dismiss(reminder);
                        if (saved && context.mounted) {
                          Navigator.pop(context, false);
                        }
                      },
                child: Text(secondary),
              ),
              FilledButton(
                onPressed: state.saving
                    ? null
                    : () => Navigator.pop(context, true),
                child: Text(primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
