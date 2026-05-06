import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/legacy_storage_are_you_sure_screen.dart';
import 'package:bb_mobile/features/wallet/ui/screens/legacy_storage_warning_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LegacyStorageWarningOverlay extends StatelessWidget {
  const LegacyStorageWarningOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      buildWhen: (previous, current) =>
          previous.showLegacyStorageWarning() !=
              current.showLegacyStorageWarning() ||
          previous.hasNoBackup() != current.hasNoBackup(),
      builder: (context, state) {
        return Stack(
          children: [
            child,
            if (state.showLegacyStorageWarning())
              _LegacyStorageWarningBlocker(hasNoBackup: state.hasNoBackup()),
          ],
        );
      },
    );
  }
}

class _LegacyStorageWarningBlocker extends StatefulWidget {
  const _LegacyStorageWarningBlocker({required this.hasNoBackup});

  final bool hasNoBackup;

  @override
  State<_LegacyStorageWarningBlocker> createState() =>
      _LegacyStorageWarningBlockerState();
}

class _LegacyStorageWarningBlockerState
    extends State<_LegacyStorageWarningBlocker> {
  bool _showAreYouSure = false;
  bool? _dbHasNoBackup;

  @override
  void initState() {
    super.initState();
    _refreshFromDb();
  }

  Future<void> _refreshFromDb() async {
    final needed = await locator<CheckBackupNeededUsecase>().execute();
    if (!mounted) return;
    setState(() => _dbHasNoBackup = needed);
  }

  Future<void> _backupNow() async {
    await context.pushNamed(BackupSettingsSubroute.backupOptions.name);
    if (!mounted) return;
    await _refreshFromDb();
  }

  void _dismiss() {
    context.read<WalletBloc>().add(const DismissLegacyStorageWarning());
  }

  void _acknowledgeRisk() {
    if (_effectiveHasNoBackup) {
      setState(() => _showAreYouSure = true);
    } else {
      _dismiss();
    }
  }

  bool get _effectiveHasNoBackup => _dbHasNoBackup ?? widget.hasNoBackup;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: _showAreYouSure
          ? LegacyStorageAreYouSureScreen(
              onBackupNow: _backupNow,
              onConfirmContinue: _dismiss,
            )
          : LegacyStorageWarningScreen(
              hasNoBackup: _effectiveHasNoBackup,
              onBackupNow: _backupNow,
              onAcknowledgeRisk: _acknowledgeRisk,
            ),
    );
  }
}
