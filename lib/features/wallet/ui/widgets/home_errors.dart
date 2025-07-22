import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/backup_card.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomeWarnings extends StatelessWidget {
  const HomeWarnings({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      buildWhen:
          (previous, current) =>
              previous.showBackupWarning() != current.showBackupWarning() ||
              previous.warnings != current.warnings,
      builder: (context, state) {
        final showBackupWarning = state.showBackupWarning();
        final serverWarning = state.warnings;

        if (!showBackupWarning && serverWarning.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(left: 13.0, right: 13, top: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBackupWarning)
                BackupCard(
                  onTap:
                      () => context.pushNamed(
                        BackupSettingsSubroute.backupOptions.name,
                      ),
                ),

              for (final warning in serverWarning) ...[
                const Gap(5),
                InfoCard(
                  title: warning.title,
                  description: warning.description,
                  tagColor: context.colour.error,
                  bgColor: context.colour.secondaryFixedDim,
                  onTap: () => context.pushNamed(warning.actionRoute),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
