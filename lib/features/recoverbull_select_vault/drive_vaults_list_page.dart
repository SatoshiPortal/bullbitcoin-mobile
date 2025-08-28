import 'package:bb_mobile/core/recoverbull/domain/entity/bull_backup.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/cubit.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/state.dart';
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
    final cubit = context.read<RecoverBullSelectVaultCubit>();

    final error = state.error;
    final selectedBackup = state.selectedBackup;
    final driveMetadata = state.driveMetadata;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () {
            cubit.clearSelectedBackup();
            if (state.selectedBackup == null) {
              context.pop();
            }
          },
          title: "Drive Backups",
        ),
      ),

      body:
          error != null
              ? Center(child: Text('Error: $error'))
              : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ...List.generate(driveMetadata.length, (index) {
                      final driveBackupMetadata = driveMetadata[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _BackupItem(
                          driveFileMetadata: driveBackupMetadata,
                        ),
                      );
                    }),
                  ],
                ),
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

    return ListTile(
      title: Text(driveFileMetadata.createdTime.toLocal().toString()),
      onTap: () => cubit.selectDriveBackup(driveFileMetadata),
    );
  }
}

class BullBackupWidget extends StatelessWidget {
  final BullBackupEntity backup;
  const BullBackupWidget({super.key, required this.backup});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          BBText(backup.filename, style: context.font.headlineMedium),
          Text(backup.derivationPath),
          Text(backup.id),
          Text(backup.createdAt.toString()),
          Text(backup.toFile()),
          TextButton(onPressed: () {}, child: const Text('Confirm')),
        ],
      ),
    );
  }
}
