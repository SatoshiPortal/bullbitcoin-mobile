import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
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
    final keyServerOffline = context.select(
      (HomeBloc bloc) => bloc.state.keyServerOffline,
    );
    final showBackupWarning = context.select(
      (HomeBloc bloc) => bloc.state.showBackupWarning(),
    );
    final warningsExist = keyServerOffline || showBackupWarning;
    if (!warningsExist) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 13.0, right: 13, top: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBackupWarning)
            BackupCard(
              onTap: () {
                // goto the backup-settings route
                context.pushNamed(
                  BackupSettingsSubroute.backupOptions.name,
                );
                // how to goto a subroute in settings?
              },
            ),
          const Gap(8),
          if (keyServerOffline)
            InfoCard(
              title: 'Key Server Offline',
              description: "Report the issue to support",
              tagColor: context.colour.error,
              bgColor: context.colour.secondaryFixedDim,
            ),
        ],
      ),
    );
  }
}
