import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/status_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackupSuccessScreen extends StatelessWidget {
  const BackupSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusScreen(
      title: context.loc.backupWalletSuccessTitle,
      description: context.loc.backupWalletSuccessDescription,
      isLoading: false,
      buttonText: context.loc.backupWalletSuccessTestButton,
      onTap:
          () => context.goNamed(
            BackupSettingsSubroute.testbackupOptions.name,
            extra: false,
          ),
    );
  }
}
