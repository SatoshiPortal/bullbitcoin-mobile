import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/loading/progress_screen.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/selectors/backup_provider_selector.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
    return BlocListener<BackupSettingsCubit, BackupSettingsState>(
      listener: (context, state) {
        if (state.selectedBackupFile != null) {
          // Navigate to backup key display screen
          context.pushNamed(
            BackupSettingsSubroute.viewBackupKey.name,
            extra: state.selectedBackupFile,
          );
          // Clear the selectedBackupFile to prevent double navigation
          context.read<BackupSettingsCubit>().clearDownloadedData();
        }
        if (state.error != null) {
          log.severe('Provider selection failed: ${state.error}');
          // Show error to user
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error.toString())));
          context.read<BackupSettingsCubit>().clearDownloadedData();
        }
      },
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

          return _buildScaffold(context);
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: "Choose vault location",
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
  }
}
