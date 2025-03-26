import 'package:bb_mobile/recover_wallet/domain/entities/backup_info.dart';
import 'package:bb_mobile/recover_wallet/ui/screens/encrypted_vault/choose_encrypted_vault_provider_screen.dart';
import 'package:bb_mobile/recover_wallet/ui/screens/encrypted_vault/fetched_backup_info_screen.dart';
import 'package:bb_mobile/recover_wallet/ui/screens/physical/recover_wallet_flow.dart';

import 'package:go_router/go_router.dart';

enum RecoverWalletSubroute {
  chooseRecoverProvider('choose-encrypted-provider'),
  backupInfo('backup-info'),
  physical('recover-physical');

  final String path;

  const RecoverWalletSubroute(this.path);
}

class RecoverWalletRouter {
  static final routes = [
    GoRoute(
      name: RecoverWalletSubroute.chooseRecoverProvider.name,
      path: RecoverWalletSubroute.chooseRecoverProvider.path,
      builder: (context, state) => ChooseVaultProviderScreen(
        fromOnboarding: (state.extra as bool?) ?? false,
      ),
    ),
    GoRoute(
      name: RecoverWalletSubroute.backupInfo.name,
      path: RecoverWalletSubroute.backupInfo.path,
      builder: (context, state) {
        final backupInfo = state.extra! as (BackupInfo, bool);
        return FetchedBackupInfoScreen(
          encryptedInfo: backupInfo.$1,
          fromOnboarding: backupInfo.$2,
        );
      },
    ),
    GoRoute(
      name: RecoverWalletSubroute.physical.name,
      path: RecoverWalletSubroute.physical.path,
      builder: (context, state) => RecoverPhysicalWalletFlow(
        fromOnboarding: (state.extra as bool?) ?? false,
      ),
    ),
  ];
}
