import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/data_backup_file_actions.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_backup_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_backup_words_recovery_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_backup_contents_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_backup_settings_screen.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_backup_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_contents_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_file_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_backup_recovery_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_recovery_words_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_recovery_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_words_recovery_screen.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_options_screen.dart';
import 'package:go_router/go_router.dart';

enum BackupSettingsFlow { backup, test }

class BackupOptionsArgs {
  final BackupSettingsFlow flow;
  final bool hasPhysicalBackup;
  final bool hasEncryptedBackup;

  const BackupOptionsArgs({
    required this.flow,
    required this.hasPhysicalBackup,
    required this.hasEncryptedBackup,
  });
}

enum BackupSettingsSubroute {
  backupOptions('backup-options');

  final String path;

  const BackupSettingsSubroute(this.path);
}

class BackupSettingsSettingsRouter {
  static final route = GoRoute(
    name: BackupSettingsSubroute.backupOptions.name,
    path: BackupSettingsSubroute.backupOptions.path,
    builder: (context, state) {
      final extra = state.extra;
      return switch (extra) {
        BackupOptionsArgs() => BackupOptionsScreen(
          flow: extra.flow,
          hasPhysicalBackup: extra.hasPhysicalBackup,
          hasEncryptedBackup: extra.hasEncryptedBackup,
        ),
        _ => BackupOptionsScreen(
          flow: extra as BackupSettingsFlow? ?? BackupSettingsFlow.backup,
        ),
      };
    },
  );
}

enum BackupSettingsRoute {
  dataContents('/data-backup/contents'),
  dataRecoverWords('/data-backup/recover/words'),
  vaultWords('/bullvault/recover/words'),
  dataRecovery('/data-backup/recover'),
  dataWords('/data-backup/words');

  final String path;
  const BackupSettingsRoute(this.path);
}

class DataBackupRecoveryArgs {
  final WalletBackupInspection? inspection;
  final bool enableAfterRecovery;
  final Map<String, String?> initialWalletLabels;
  const DataBackupRecoveryArgs({
    this.inspection,
    this.enableAfterRecovery = false,
    this.initialWalletLabels = const {},
  });
}

abstract final class BackupSettingsRouter {
  static List<GoRoute> recoveryRoutes({
    required void Function(VaultBackupRecovery) onVaultsRecovered,
    required void Function(WalletBackupSnapshot, WalletBackupRecovery)
    onDataRecovered,
  }) => [
    GoRoute(
      name: SettingsRoute.dataBackup.name,
      path: SettingsRoute.dataBackup.path,
      builder: (context, _) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                locator<DataBackupSettingsCubit>()
                  ..start(retryPublication: true),
          ),
          BlocProvider(create: (_) => locator<DataBackupFileCubit>()),
        ],
        child: DataBackupSettingsScreen(
          onContents: (server) => context.pushNamed<void>(
            BackupSettingsRoute.dataContents.name,
            extra: server,
          ),
          onWords: () =>
              context.pushNamed<void>(BackupSettingsRoute.dataWords.name),
          onRecovery: () =>
              context.pushNamed<void>(BackupSettingsRoute.dataRecovery.name),
          onRecoverWords: () => context.pushNamed<void>(
            BackupSettingsRoute.dataRecoverWords.name,
          ),
          fileActions: DataBackupFileActions(onRecovered: onDataRecovered),
        ),
      ),
    ),
    GoRoute(
      name: BackupSettingsRoute.dataContents.name,
      path: BackupSettingsRoute.dataContents.path,
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => locator<DataBackupSettingsCubit>()..start(),
          ),
          BlocProvider(
            create: (_) =>
                locator<DataBackupContentsCubit>()
                  ..load(server: state.extra == true),
          ),
        ],
        child: DataBackupContentsScreen(
          onRecover: (inspection) => context.pushNamed<void>(
            BackupSettingsRoute.dataRecovery.name,
            extra: DataBackupRecoveryArgs(inspection: inspection),
          ),
        ),
      ),
    ),
    GoRoute(
      name: BackupSettingsRoute.dataRecoverWords.name,
      path: BackupSettingsRoute.dataRecoverWords.path,
      builder: (_, _) => BlocProvider(
        create: (_) => locator<DataBackupRecoveryCubit>(),
        child: DataBackupWordsRecoveryScreen(
          onRecovered: (inspection, result) =>
              onDataRecovered(inspection.snapshot!, result),
        ),
      ),
    ),
    GoRoute(
      name: BullVaultFacade.backupRouteName,
      path: '/bullvault/:walletId/backup',
      builder: (context, state) {
        final walletId = state.pathParameters['walletId']!;
        return BlocProvider(
          create: (_) => locator<VaultBackupCubit>()..load(walletId),
          child: VaultBackupScreen(
            walletId: walletId,
            onOpenDataBackup: () =>
                context.pushNamed<void>(SettingsRoute.dataBackup.name),
          ),
        );
      },
    ),
    GoRoute(
      name: BullVaultFacade.restoreRouteName,
      path: '/bullvault/restore',
      builder: (context, _) => BlocProvider(
        create: (_) => locator<VaultRecoveryCubit>()..search(),
        child: VaultRecoveryScreen(
          onRecovered: onVaultsRecovered,
          onDescriptor: () =>
              context.pushNamed(BullVaultFacade.descriptorRestoreRouteName),
          onWords: () => context.pushNamed(BackupSettingsRoute.vaultWords.name),
        ),
      ),
    ),
    GoRoute(
      name: BackupSettingsRoute.vaultWords.name,
      path: BackupSettingsRoute.vaultWords.path,
      builder: (_, _) => BlocProvider(
        create: (_) => locator<VaultRecoveryCubit>(),
        child: VaultWordsRecoveryScreen(onRecovered: onVaultsRecovered),
      ),
    ),
    GoRoute(
      name: BackupSettingsRoute.dataRecovery.name,
      path: BackupSettingsRoute.dataRecovery.path,
      builder: (_, state) {
        final args = state.extra is DataBackupRecoveryArgs
            ? state.extra! as DataBackupRecoveryArgs
            : const DataBackupRecoveryArgs();
        return BlocProvider(
          create: (_) {
            final cubit = locator<DataBackupRecoveryCubit>(
              param1: args.inspection,
            );
            if (args.inspection == null) cubit.inspect();
            return cubit;
          },
          child: DataBackupRecoveryScreen(
            onRecovered: (inspection, result) =>
                onDataRecovered(inspection.snapshot!, result),
            enableAfterRecovery: args.enableAfterRecovery,
            initialWalletLabels: args.initialWalletLabels,
          ),
        );
      },
    ),
    GoRoute(
      name: BackupSettingsRoute.dataWords.name,
      path: BackupSettingsRoute.dataWords.path,
      builder: (_, _) => const DataRecoveryWordsScreen(),
    ),
  ];
}
