import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/ui/components/loading/status_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackupSuccessScreen extends StatelessWidget {
  const BackupSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusScreen(
      title: 'Backup completed!',
      description:
          "Now let's test your backup to make sure everything was done properly.",
      isLoading: false,
      buttonText: 'Test Backup',
      onTap: () => context.goNamed(
        SettingsSubroute.backupSettings.name,
        extra: false,
      ),
    );
  }
}
