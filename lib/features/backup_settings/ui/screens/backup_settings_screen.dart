import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<BackupSettingsCubit>()..checkBackupStatus(),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BackupSettingsCubit, BackupSettingsState>(
      listener: (context, state) {
        // Add global state handling if needed
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            forceMaterialTransparency: true,
            automaticallyImplyLeading: false,
            flexibleSpace: TopBar(
              title: context.loc.backupSettingsScreenTitle,
              onBack: () => context.pop(),
            ),
          ),
          body: SafeArea(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Gap(20),
                        _BackupTestStatusWidget(),
                        Gap(30),
                        _RecoverOrTestBackupButton(),
                        Gap(5),
                        _StartBackupButton(),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _BackupTestStatusWidget extends StatelessWidget {
  const _BackupTestStatusWidget();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusRow(
              label: 'Physical Backup',
              isTested: state.isDefaultPhysicalBackupTested,
            ),
            const Gap(15),
            _StatusRow(
              label: 'Encrypted Vault',
              isTested: state.isDefaultEncryptedBackupTested,
            ),
          ],
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isTested;

  const _StatusRow({
    required this.label,
    required this.isTested,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: context.font.bodyMedium,
        ),
        const Spacer(),
        Text(
          isTested ? 'Tested' : 'Not Tested',
          style: context.font.bodyMedium?.copyWith(
            color:
                isTested ? context.colour.inverseSurface : context.colour.error,
          ),
        ),
      ],
    );
  }
}

class _RecoverOrTestBackupButton extends StatelessWidget {
  const _RecoverOrTestBackupButton();

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: 'Recover or Test Backup',
      onPressed: () => context.pushNamed(
        BackupSettingsSubroute.recoverOptions.name,
        extra: false,
      ),
      borderColor: context.colour.secondary,
      outlined: true,
      bgColor: Colors.transparent,
      textColor: context.colour.secondary,
    );
  }
}

class _StartBackupButton extends StatelessWidget {
  const _StartBackupButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: BBButton.big(
        label: 'Start Backup',
        onPressed: () => context.pushNamed(
          BackupSettingsSubroute.backupOptions.name,
        ),
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
