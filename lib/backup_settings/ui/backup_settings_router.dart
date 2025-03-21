import 'package:bb_mobile/backup_settings/ui/screens/backup_settings_screen.dart';
import 'package:bb_mobile/backup_wallet/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/backup_wallet/ui/screens/backup_security_info_screen.dart';
import 'package:go_router/go_router.dart';

enum BackupSettingsSubroute {
  backupOptions('backup-options'),
  backupSecurityInfo('backup-security-info'),
  recoverOptions('recover-options'),
  encryptedVaultBackup('encrypted-vault-backup'),
  physicalBackup('physical-backup'),
  encryptedVaultRecover('encrypted-vault-recover'),
  physicalRecover('physical-recover');

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
      name: BackupSettingsSubroute.backupSecurityInfo.name,
      path: BackupSettingsSubroute.backupSecurityInfo.path,
      builder: (context, state) => BackupSecurityInfoScreen(
        backupOption: state.extra as String? ?? 'encrypted-vault',
      ),
    ),
    // GoRoute(
    //   name: BackupSettingsSubroute.recoverOptions.name,
    //   path: BackupSettingsSubroute.recoverOptions.path,
    //   builder: (context, state) => const RecoverOptionsScreen(),
    // ),

    // GoRoute(
    //   name: BackupSettingsSubroute.encryptedVaultBackup.name,
    //   path: BackupSettingsSubroute.encryptedVaultBackup.path,
    //   builder: (context, state) => const EncryptedVaultBackupScreen(),
    // ),
    // GoRoute(
    //   name: BackupSettingsSubroute.physicalBackup.name,
    //   path: BackupSettingsSubroute.physicalBackup.path,
    //   builder: (context, state) => const PhysicalBackupScreen(),
    // ),

    // GoRoute(
    //   name: BackupSettingsSubroute.encryptedVaultRecover.name,
    //   path: BackupSettingsSubroute.encryptedVaultRecover.path,
    //   builder: (context, state) => const EncryptedVaultRecoverScreen(),
    // ),
    // GoRoute(
    //   name: BackupSettingsSubroute.physicalRecover.name,
    //   path: BackupSettingsSubroute.physicalRecover.path,
    //   builder: (context, state) => const PhysicalRecoverScreen(),
    // ),
  ];
}
