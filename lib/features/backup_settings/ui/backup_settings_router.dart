import 'package:bb_mobile/features/backup_wallet/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/test_backup_options_screen.dart';
import 'package:go_router/go_router.dart';

enum BackupSettingsSubroute {
  backupOptions('backup-options'),
  testbackupOptions('test-backup-options');

  final String path;

  const BackupSettingsSubroute(this.path);
}

class BackupSettingsSettingsRouter {
  static final routes = [
    GoRoute(
      name: BackupSettingsSubroute.backupOptions.name,
      path: BackupSettingsSubroute.backupOptions.path,
      builder: (context, state) => const BackupOptionsScreen(),
    ),
    GoRoute(
      name: BackupSettingsSubroute.testbackupOptions.name,
      path: BackupSettingsSubroute.testbackupOptions.path,
      builder: (context, state) => const TestBackupOptionsScreen(),
    ),
  ];
}
