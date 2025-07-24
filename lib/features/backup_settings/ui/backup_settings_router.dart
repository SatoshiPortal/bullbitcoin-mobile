import 'package:bb_mobile/features/backup_settings/ui/screens/choose_vault_provider_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/view_backup_key_screen.dart';
import 'package:bb_mobile/features/backup_wallet/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/test_backup_options_screen.dart';
import 'package:go_router/go_router.dart';

enum BackupSettingsSubroute {
  backupOptions('backup-options'),
  testbackupOptions('test-backup-options'),
  chooseVaultProvider('choose-vault-provider'),
  viewBackupKey('view-backup-key');

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
    GoRoute(
      name: BackupSettingsSubroute.chooseVaultProvider.name,
      path: BackupSettingsSubroute.chooseVaultProvider.path,
      builder: (context, state) => const ChooseVaultProviderScreen(),
    ),
    GoRoute(
      name: BackupSettingsSubroute.viewBackupKey.name,
      path: BackupSettingsSubroute.viewBackupKey.path,
      builder: (context, state) {
        final backupFile = state.extra! as String;
        return ViewBackupKeyScreen(backupFile: backupFile);
      },
    ),
  ];
}
