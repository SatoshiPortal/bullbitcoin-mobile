import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/cubit.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DriveVaultsListPage extends StatelessWidget {
  const DriveVaultsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context
        .select<RecoverBullSelectVaultCubit, RecoverBullSelectVaultState>(
          (cubit) => cubit.state,
        );

    final error = state.error;
    final driveMetadata = state.driveMetadata;

    final cubit = context.read<RecoverBullSelectVaultCubit>();

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () {
            cubit.clearSelectedBackup();
            if (state.selectedBackup == null) context.pop();
          },
          title: "Drive Backups",
        ),
      ),

      body: Column(
        children: [
          FadingLinearProgress(
            trigger: state.isLoading || state.isSelectingBackup,
            backgroundColor: context.colour.surface,
            foregroundColor: context.colour.primary,
            height: 2.0,
          ),
          Expanded(
            child:
                error != null
                    ? Center(child: Text('Error: $error'))
                    : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (!state.isLoading && driveMetadata.isEmpty)
                              const Center(child: Text('No backups found')),

                            ...List.generate(driveMetadata.length, (index) {
                              final driveBackupMetadata = driveMetadata[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: _BackupItem(
                                  driveFileMetadata: driveBackupMetadata,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _BackupItem extends StatelessWidget {
  final DriveFileMetadata driveFileMetadata;

  const _BackupItem({required this.driveFileMetadata});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecoverBullSelectVaultCubit>();
    final state = context
        .select<RecoverBullSelectVaultCubit, RecoverBullSelectVaultState>(
          (cubit) => cubit.state,
        );

    return ListTile(
      title: Text(driveFileMetadata.createdTime.toLocal().toString()),
      onTap:
          state.isSelectingBackup
              ? null
              : () => cubit.selectDriveBackup(driveFileMetadata),
      enabled: !state.isSelectingBackup,
    );
  }
}
