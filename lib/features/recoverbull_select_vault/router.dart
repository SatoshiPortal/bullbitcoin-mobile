import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_backups_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/cubit.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/state.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/ui/drive_vaults_list_page.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/ui/select_custom_location_page.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/ui/select_provider_page.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/ui/vault_selected_page.dart';
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
  static final route = ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create:
            (_) => RecoverBullSelectVaultCubit(
              fetchAllDriveFileMetadataUsecase:
                  locator<FetchAllDriveFileMetadataUsecase>(),
              fetchDriveBackupUsecase: locator<FetchVaultFromDriveUsecase>(),
              selectFileFromPathUsecase: locator<SelectFileFromPathUsecase>(),
            ),
        child: MultiBlocListener(
          listeners: [
            BlocListener<
              RecoverBullSelectVaultCubit,
              RecoverBullSelectVaultState
            >(
              listenWhen:
                  (previous, current) =>
                      previous.selectedProvider != current.selectedProvider &&
                      current.selectedProvider != null,
              listener: (context, state) {
                switch (state.selectedProvider) {
                  case BackupProviderType.googleDrive ||
                      BackupProviderType.custom:
                    context.pushNamed(
                      RecoverBullSelectVault.selectVault.name,
                      extra: state.selectedProvider,
                    );
                  default:
                    break;
                }
              },
            ),
            BlocListener<
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
            ),
          ],
          child: child,
        ),
      );
    },
    routes: [
      GoRoute(
        name: RecoverBullSelectVault.selectProvider.name,
        path: RecoverBullSelectVault.selectProvider.path,
        builder: (context, state) => const SelectProviderPage(),
      ),
      GoRoute(
        name: RecoverBullSelectVault.selectVault.name,
        path: RecoverBullSelectVault.selectVault.path,
        builder: (context, state) {
          final selectedProvider = state.extra as BackupProviderType?;

          if (selectedProvider == BackupProviderType.googleDrive) {
            context.read<RecoverBullSelectVaultCubit>().fetchDriveBackups();
          }

          return switch (selectedProvider) {
            BackupProviderType.googleDrive => const DriveVaultsListPage(),
            BackupProviderType.custom => const SelectCustomLocationPage(),
            _ => const Scaffold(body: Placeholder()),
          };
        },
      ),
      GoRoute(
        path: RecoverBullSelectVault.vaultSelected.path,
        name: RecoverBullSelectVault.vaultSelected.name,
        builder: (context, state) {
          final backup = state.extra! as EncryptedVault;
          return VaultSelectedPage(backup: backup);
        },
      ),
    ],
  );
}
