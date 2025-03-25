import 'package:bb_mobile/backup_wallet/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/backup_wallet/ui/screens/backup_security_info_screen.dart';
import 'package:bb_mobile/backup_wallet/ui/screens/choose_encrypted_vault_provider_screen.dart';
import 'package:bb_mobile/key_server/ui/screens/recover_with_backup_key_screen.dart';
import 'package:bb_mobile/recover_wallet/domain/entities/backup_info.dart';
import 'package:bb_mobile/recover_wallet/ui/screens/choose_recover_encrypted_vault_provider_screen.dart';
import 'package:bb_mobile/recover_wallet/ui/screens/fetched_backup_info_screen.dart';
import 'package:bb_mobile/recover_wallet/ui/screens/recover_options_screen.dart';
import 'package:go_router/go_router.dart';

enum BackupSettingsSubroute {
  backupOptions('backup-options'),
  recoverOptions('recover-options'),

  backupSecurityInfo('backup-security-info'),

  encryptedVaultBackupFlow('encrypted-vault-backup-flow'),
  physicalBackupFlow('physical-backup-flow'),

  encryptedVaultRecoverFlow('encrypted-vault-recover-flow'),
  fetchedBackupInfo('fetched-backup-info'),

  recoverWithBackupKeyScreen('recover-with-backup-key'),
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
    GoRoute(
      name: BackupSettingsSubroute.recoverOptions.name,
      path: BackupSettingsSubroute.recoverOptions.path,
      builder: (context, state) => const RecoverOptionsScreen(),
    ),

    // GoRoute(
    //   name: BackupSettingsSubroute.physicalBackup.name,
    //   path: BackupSettingsSubroute.physicalBackup.path,
    //   builder: (context, state) => const PhysicalBackupScreen(),
    // ),

    GoRoute(
      name: BackupSettingsSubroute.encryptedVaultRecoverFlow.name,
      path: BackupSettingsSubroute.encryptedVaultRecoverFlow.path,
      builder: (context, state) => ChooserRecoverVaultLocationScreen(
        isRecovering: state.extra! as bool,
      ),
    ),
    GoRoute(
      name: BackupSettingsSubroute.fetchedBackupInfo.name,
      path: BackupSettingsSubroute.fetchedBackupInfo.path,
      builder: (context, state) {
        final backupInfo = state.extra! as (BackupInfo, bool);
        return FetchedBackupInfoScreen(
          encryptedInfo: backupInfo.$1,
          isRecovering: backupInfo.$2,
        );
      },
    ),

    GoRoute(
      name: BackupSettingsSubroute.recoverWithBackupKeyScreen.name,
      path: BackupSettingsSubroute.recoverWithBackupKeyScreen.path,
      builder: (context, state) => const RecoverWithBackupKeyScreen(),
    ),
  ];
}
