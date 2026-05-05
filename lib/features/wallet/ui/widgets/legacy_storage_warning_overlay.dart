import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/legacy_storage_are_you_sure_screen.dart';
import 'package:bb_mobile/features/wallet/ui/screens/legacy_storage_warning_screen.dart';
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

  void _backupNow() {
    context.pushNamed(BackupSettingsSubroute.backupOptions.name);
  }

  void _dismiss() {
    context.read<WalletBloc>().add(const DismissLegacyStorageWarning());
  }

  void _acknowledgeRisk() {
    if (widget.hasNoBackup) {
      setState(() => _showAreYouSure = true);
    } else {
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: _showAreYouSure
          ? LegacyStorageAreYouSureScreen(
              onBackupNow: _backupNow,
              onConfirmContinue: _dismiss,
            )
          : LegacyStorageWarningScreen(
              hasNoBackup: widget.hasNoBackup,
              onBackupNow: _backupNow,
              onAcknowledgeRisk: _acknowledgeRisk,
            ),
    );
  }
}
