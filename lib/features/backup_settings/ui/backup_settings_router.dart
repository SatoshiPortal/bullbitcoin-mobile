import 'package:bb_mobile/features/backup_settings/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_metadata_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_recovery_manifest_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:go_router/go_router.dart';

enum BackupSettingsFlow { backup, test }

enum BackupSettingsSubroute {
  backupOptions('backup-options'),
  walletManifest('wallet-manifest'),
  walletMetadata('wallet-metadata');

  final String path;

  const BackupSettingsSubroute(this.path);
}

class BackupSettingsSettingsRouter {
  static final routes = <RouteBase>[
    GoRoute(
      name: BackupSettingsSubroute.backupOptions.name,
      path: BackupSettingsSubroute.backupOptions.path,
      builder: (context, state) {
        final flow =
            state.extra as BackupSettingsFlow? ?? BackupSettingsFlow.backup;
        return BackupOptionsScreen(flow: flow);
      },
    ),
    GoRoute(
      name: BackupSettingsSubroute.walletManifest.name,
      path: BackupSettingsSubroute.walletManifest.path,
      builder: (_, state) => WalletRecoveryManifestScreen(
        wallets:
            state.extra as List<WalletBackupWalletSummary>? ??
            const <WalletBackupWalletSummary>[],
      ),
    ),
    GoRoute(
      name: BackupSettingsSubroute.walletMetadata.name,
      path: BackupSettingsSubroute.walletMetadata.path,
      builder: (_, state) => WalletMetadataScreen(
        metadata:
            state.extra as List<WalletBackupMetadataSummary>? ??
            const <WalletBackupMetadataSummary>[],
      ),
    ),
  ];
}
