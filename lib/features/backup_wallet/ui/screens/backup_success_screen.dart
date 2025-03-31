import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/ui/components/loading/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackupSuccessScreen extends StatelessWidget {
  const BackupSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProgressScreen(
      description:
          'Now let’s test your backup to make sure everything was done properly.',
      title: 'Backup completed!',
      isLoading: false,
      buttonText: 'Test Backup',
      onTap: () => context.goNamed(
        SettingsSubroute.backupSettings.name,
        extra: false,
      ),
    );
  }
}
