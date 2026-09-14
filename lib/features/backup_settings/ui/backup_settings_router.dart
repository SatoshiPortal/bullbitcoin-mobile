import 'dart:typed_data';

import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_words_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_destinations_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_words_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_words_recovery_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_cosigner_key_recovery_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_destinations_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_recovery_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_metadata_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_recovery_manifest_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_vaults_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_backup_screen.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_backup_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  backupWords('backup-words'),
  vaultRecoveryCosignerKey('cosigner-key'),
  vaultRecoveryBackupWords('backup-words-entry'),
  vaultRecoveryMobileKey('mobile-key'),
  walletManifest('wallet-manifest'),
  walletMetadata('wallet-metadata'),
  walletVaults('wallet-vaults');

  final String path;

  const BackupSettingsSubroute(this.path);
}

class BackupSettingsSettingsRouter {
  /// The public `/bullvault/restore` entry, with its four manual children.
  ///
  /// The landing lives here because it is the only place that can compose the
  /// vault feature, the backup server and the relays; the vault feature keeps
  /// the route name and builds the "Import descriptor" child itself, so no
  /// BullVault to BackupSettings import is created.
  static final vaultRecoveryRoutes = <RouteBase>[
    GoRoute(
      name: BullVaultFacade.restoreRouteName,
      path: '/bullvault/restore',
      builder: (_, _) => BlocProvider(
        create: (_) => locator<VaultRecoveryCubit>()..discover(),
        child: const VaultRecoveryScreen(),
      ),
      routes: [
        BullVaultRouter.importDescriptorRoute(
          onEncryptedDescriptorFile: (context, bytes) => context.pushNamed(
            BackupSettingsSubroute.vaultRecoveryCosignerKey.name,
            extra: bytes,
          ),
        ),
        GoRoute(
          name: BackupSettingsSubroute.vaultRecoveryCosignerKey.name,
          path: BackupSettingsSubroute.vaultRecoveryCosignerKey.path,
          builder: (_, state) => BlocProvider(
            create: (_) => locator<VaultRecoveryCubit>(),
            child: VaultCosignerKeyRecoveryScreen(
              initialArtifact: state.extra as Uint8List?,
            ),
          ),
        ),
        GoRoute(
          name: BackupSettingsSubroute.vaultRecoveryBackupWords.name,
          path: BackupSettingsSubroute.vaultRecoveryBackupWords.path,
          builder: (_, _) => BlocProvider(
            create: (_) => locator<VaultRecoveryCubit>(),
            child: const VaultWordsRecoveryScreen.backupWords(),
          ),
        ),
        GoRoute(
          name: BackupSettingsSubroute.vaultRecoveryMobileKey.name,
          path: BackupSettingsSubroute.vaultRecoveryMobileKey.path,
          builder: (_, _) => BlocProvider(
            create: (_) => locator<VaultRecoveryCubit>(),
            child: const VaultWordsRecoveryScreen.mobileKey(),
          ),
        ),
      ],
    ),
  ];

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
      name: BackupSettingsSubroute.backupWords.name,
      path: BackupSettingsSubroute.backupWords.path,
      builder: (_, state) => BlocProvider(
        create: (_) => locator<BackupWordsCubit>(),
        child: BackupWordsScreen(originFingerprint: state.extra as String?),
      ),
    ),
    GoRoute(
      name: BullVaultFacade.backupDestinationsRouteName,
      path: 'bullvault/:walletId/destinations',
      builder: (_, state) => BlocProvider(
        create: (_) => locator<VaultDestinationsCubit>(
          param1: state.pathParameters['walletId']!,
        )..load(),
        child: const VaultDestinationsScreen(),
      ),
    ),
    GoRoute(
      name: BullVaultFacade.backupRouteName,
      path: 'bullvault/:walletId',
      builder: (_, state) => BlocProvider(
        create: (_) =>
            locator<VaultBackupCubit>(param1: state.pathParameters['walletId']!)
              ..load(),
        child: const VaultBackupScreen(),
      ),
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
        contents:
            state.extra as WalletBackupContents? ??
            const WalletBackupContents(
              labelCount: 0,
              frozenCoinCount: 0,
              walletPreferenceCount: 0,
            ),
      ),
    ),
    GoRoute(
      name: BackupSettingsSubroute.walletVaults.name,
      path: BackupSettingsSubroute.walletVaults.path,
      builder: (_, state) =>
          WalletVaultsScreen(contents: state.extra as WalletBackupContents?),
    ),
  ];
}
