import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core/widgets/selectors/backup_provider_selector.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ChooseVaultProviderScreen extends StatefulWidget {
  const ChooseVaultProviderScreen({super.key});

  @override
  State<ChooseVaultProviderScreen> createState() =>
      _ChooseVaultProviderScreenState();
}

class _ChooseVaultProviderScreenState extends State<ChooseVaultProviderScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<BackupSettingsCubit>(),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  void onProviderSelected(BuildContext context, BackupProviderType provider) {
    switch (provider) {
      case BackupProviderType.googleDrive:
        context.read<BackupSettingsCubit>().selectGoogleDriveProvider();
      case BackupProviderType.custom:
        context.read<BackupSettingsCubit>().selectFileSystemProvider();
      case BackupProviderType.iCloud:
        log.info('iCloud, not supported yet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BackupSettingsCubit, BackupSettingsState>(
          listenWhen:
              (previous, current) =>
                  previous.selectedBackupFile != current.selectedBackupFile &&
                  current.selectedBackupFile != null,
          listener: (context, state) {
            context.pushNamed(
              BackupSettingsSubroute.viewBackupKey.name,
              extra: state.selectedBackupFile,
            );
            context.read<BackupSettingsCubit>().clearDownloadedData();
          },
        ),

        BlocListener<BackupSettingsCubit, BackupSettingsState>(
          listenWhen:
              (previous, current) =>
                  previous.error != current.error && current.error != null,
          listener: (context, state) {
            context.read<BackupSettingsCubit>().clearDownloadedData();
          },
        ),
      ],
      child: BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
        builder: (context, state) {
          if (state.status == BackupSettingsStatus.loading) {
            return Scaffold(
              backgroundColor: context.colour.onSecondary,
              body: const ProgressScreen(
                title: "Loading backup file...",
                description: "Please wait while we fetch your backup file.",
                isLoading: true,
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              forceMaterialTransparency: true,
              title: BBText(
                "Choose vault location",
                style: context.font.headlineMedium,
                color: context.colour.secondary,
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BackupProviderSelector(
                    onProviderSelected:
                        (provider) => onProviderSelected(context, provider),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
