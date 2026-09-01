import 'package:bb_mobile/features/backup_settings/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_metadata_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_recovery_manifest_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:go_router/go_router.dart';

enum BackupSettingsFlow { backup, test }

final class BackupOptionsArgs {
  final BackupSettingsFlow flow;
  final bool hasPhysicalBackup;
  final bool hasEncryptedBackup;

  const BackupOptionsArgs({
    required this.flow,
    this.hasPhysicalBackup = false,
    this.hasEncryptedBackup = false,
  });
}

enum BackupSettingsSubroute {
  backupOptions('backup-options'),
  walletManifest('wallet-manifest'),
  walletMetadata('wallet-metadata');

  final String path;

  const BackupSettingsSubroute(this.path);
}

class BackupSettingsSettingsRouter {
  static final walletRecoveryRoutes = <RouteBase>[
    GoRoute(
      name: BackupSettingsSubroute.backupOptions.name,
      path: BackupSettingsSubroute.backupOptions.path,
      builder: (context, state) {
        final extra = state.extra;
        final args = extra is BackupOptionsArgs
            ? extra
            : BackupOptionsArgs(
                flow: extra is BackupSettingsFlow
                    ? extra
                    : BackupSettingsFlow.backup,
              );
        return BackupOptionsScreen(
          flow: args.flow,
          hasPhysicalBackup: args.hasPhysicalBackup,
          hasEncryptedBackup: args.hasEncryptedBackup,
        );
      },
    ),
  ];

  static final dataBackupRoutes = <RouteBase>[
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
        contents:
            state.extra as WalletBackupContents? ??
            const WalletBackupContents(
              labelCount: 0,
              frozenCoinCount: 0,
              walletPreferenceCount: 0,
            ),
      ),
    ),
  ];
}
