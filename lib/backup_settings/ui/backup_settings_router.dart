import 'package:bb_mobile/backup_wallet/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/backup_wallet/ui/screens/backup_security_info_screen.dart';
import 'package:bb_mobile/backup_wallet/ui/screens/choose_encrypted_vault_provider_screen.dart';
import 'package:go_router/go_router.dart';

enum BackupSettingsSubroute {
  backupOptions('backup-options'),
  recoverOptions('recover-options'),
  backupSecurityInfo('backup-security-info'),
  encryptedVaultBackupFlow('encrypted-vault-backup-flow'),
  physicalBackupFlow('physical-backup-flow'),
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
    GoRoute(
      name: BackupSettingsSubroute.encryptedVaultBackupFlow.name,
      path: BackupSettingsSubroute.encryptedVaultBackupFlow.path,
      //TODO: Implement the backup flow screen instead
      builder: (context, state) => const ChooseVaultLocationScreen(),
    ),
    // GoRoute(
    //   name: BackupSettingsSubroute.recoverOptions.name,
    //   path: BackupSettingsSubroute.recoverOptions.path,
    //   builder: (context, state) => const RecoverOptionsScreen(),
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
