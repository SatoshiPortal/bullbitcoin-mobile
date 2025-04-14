import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/cards/backup_card.dart';
import 'package:bb_mobile/ui/components/cards/info_card.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomeErrors extends StatelessWidget {
  const HomeErrors({super.key});

  @override
  Widget build(BuildContext context) {
    final showBackupWarning = context.select(
      (HomeBloc bloc) => bloc.state.showBackupWarning(),
    );

    return BlocProvider(
      create: (context) => locator<KeyServerCubit>()..checkConnection(),
      child: BlocBuilder<KeyServerCubit, KeyServerState>(
        buildWhen: (previous, current) =>
            previous.torStatus != current.torStatus,
        builder: (context, keyServerState) {
          final isServerOffline = keyServerState.torStatus != TorStatus.online;

          if (!showBackupWarning && !isServerOffline) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(left: 13.0, right: 13, top: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBackupWarning)
                  BackupCard(
                    onTap: () => context.pushNamed(
                      BackupSettingsSubroute.backupOptions.name,
                    ),
                  ),
                if (showBackupWarning && isServerOffline) const Gap(8),
                if (isServerOffline)
                  InfoCard(
                    title: "Key Server Offline",
                    description: "Report the issue to support",
                    tagColor: context.colour.error,
                    bgColor: context.colour.secondaryFixedDim,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
