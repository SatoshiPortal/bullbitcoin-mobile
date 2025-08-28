import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/bull_backup.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_backups_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_drive_backup_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/cubit.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/drive_vaults_list_page.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/select_provider_page.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/state.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/vault_selected_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum RecoverBullSelectVault {
  selectProvider('/recoverbull/select-provider'),
  listDriveVaults('/recoverbull/drive/list'),
  selectVault('/recoverbull/select-vault'),
  vaultSelected('/recoverbull/vault-selected');

  final String path;

  const RecoverBullSelectVault(this.path);
}

class RecoverBullSelectVaultRouter {
  static final route = GoRoute(
    name: RecoverBullSelectVault.selectProvider.name,
    path: RecoverBullSelectVault.selectProvider.path,
    builder: (context, state) => const SelectProviderPage(),
    routes: [
      GoRoute(
        name: RecoverBullSelectVault.selectVault.name,
        path: RecoverBullSelectVault.selectVault.path,
        builder: (context, state) {
          final selectedProvider = state.extra as BackupProviderType?;

          return BlocProvider(
            create:
                (_) => RecoverBullSelectVaultCubit(
                  fetchAllDriveBackupsUsecase:
                      locator<FetchAllDriveBackupsUsecase>(),
                  fetchDriveBackupUsecase: locator<FetchDriveBackupUsecase>(),
                  checkWalletStatusUsecase: locator<TheDirtyUsecase>(),
                  selectedProvider: selectedProvider!,
                ),
            child: BlocListener<
              RecoverBullSelectVaultCubit,
              RecoverBullSelectVaultState
            >(
              listenWhen:
                  (previous, current) =>
                      previous.selectedBackup == null &&
                      current.selectedBackup != null,
              listener: (context, state) {
                context.pushNamed(
                  RecoverBullSelectVault.vaultSelected.name,
                  extra: state.selectedBackup,
                );
              },
              child: switch (selectedProvider) {
                BackupProviderType.googleDrive => const DriveVaultsListPage(),
                _ => const Scaffold(),
              },
            ),
          );
        },
      ),
      GoRoute(
        path: RecoverBullSelectVault.vaultSelected.path,
        name: RecoverBullSelectVault.vaultSelected.name,
        builder: (context, state) {
          final backup = state.extra! as BullBackupEntity;
          return VaultSelectedPage(backup: backup);
        },
      ),
    ],
  );
}
