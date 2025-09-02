import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/bull_backup.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_router.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class VaultSelectedPage extends StatelessWidget {
  final BullBackupEntity backup;

  const VaultSelectedPage({super.key, required this.backup});

  @override
  Widget build(BuildContext context) {
    final provider = context.select(
      (RecoverBullSelectVaultCubit cubit) => cubit.state.selectedProvider,
    );

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () {
            context.read<RecoverBullSelectVaultCubit>().clearState();
            if (provider == BackupProviderType.custom) {
              context.pop();
              context.pop();
            } else {
              context.pop();
            }
          },
          title: 'Vault Selected',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [BullBackupWidget(backup: backup)]),
      ),
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
          BBText(
            'Your vault was successfully imported',
            textAlign: TextAlign.left,
            style: context.font.bodySmall,
          ),
          const Gap(16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: context.colour.surface),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(backup.id, style: context.font.headlineMedium),
                BBText(
                  DateFormat(
                    "yyyy-MMM-dd, HH:mm:ss",
                  ).format(backup.createdAt.toLocal()),
                  style: context.font.headlineMedium,
                ),
              ],
            ),
          ),

          BBButton.big(
            label: 'Enter Backup key manually >>',
            onPressed:
                () => context.push(
                  KeyServerRoute.keyServerFlow.path,
                  extra: (
                    backup.toFile(),
                    CurrentKeyServerFlow.recoveryWithBackupKey.name,
                    true,
                  ),
                ),
            bgColor: Colors.transparent,
            textStyle: context.font.bodySmall,
            textColor: context.colour.inversePrimary,
          ),

          const Gap(16),
          BBButton.big(
            label: 'Decrypt vault',
            onPressed:
                () => context.pushNamed(
                  KeyServerRoute.keyServerFlow.name,
                  extra: (
                    backup.toFile(),
                    CurrentKeyServerFlow.recovery.name,
                    true,
                  ),
                ),
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
        ],
      ),
    );
  }
}
