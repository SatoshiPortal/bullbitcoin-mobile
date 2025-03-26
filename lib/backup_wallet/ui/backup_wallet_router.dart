import 'package:bb_mobile/backup_wallet/ui/screens/backup_security_info_screen.dart';
import 'package:bb_mobile/backup_wallet/ui/screens/choose_encrypted_vault_provider_screen.dart';

import 'package:go_router/go_router.dart';

enum BackupWalletSubroute {
  securityInfo('security-info'),
  chooseBackupProvider('choose-backup-provider'),
  //TODO: add physical backup subroutes
  physical('backup-physical'),
  ;

  final String path;

  const BackupWalletSubroute(this.path);
}

class BackupWalletRouter {
  static final routes = [
    GoRoute(
      name: BackupWalletSubroute.chooseBackupProvider.name,
      path: BackupWalletSubroute.chooseBackupProvider.path,
      builder: (context, state) => const ChooseVaultProviderScreen(),
    ),
    GoRoute(
      name: BackupWalletSubroute.securityInfo.name,
      path: BackupWalletSubroute.securityInfo.path,
      builder: (context, state) {
        return BackupSecurityInfoScreen(
          backupOption: state.extra! as String,
        );
      },
    ),
  ];
}
