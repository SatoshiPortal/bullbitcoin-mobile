import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/_utils/build_context_x.dart';
import 'package:bb_mobile/backup_settings/ui/backup_settings_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackupSettingsScreen extends StatelessWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.backupSettingsScreenTitle,
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(20),
              BackupTestStatusWidget(),
              Gap(30),
              RecoverBackupButton(),
              Gap(5),
              StartBackupButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class RecoverBackupButton extends StatelessWidget {
  const RecoverBackupButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: 'Recover Backup',
      onPressed: () => context.pushNamed(
        BackupSettingsSubroute.backupOptions.name,
      ),
      borderColor: context.colour.secondary,
      outlined: true,
      bgColor: Colors.transparent,
      textColor: context.colour.secondary,
    );
  }
}

class StartBackupButton extends StatelessWidget {
  const StartBackupButton({super.key});

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

class BackupTestStatusWidget extends StatelessWidget {
  const BackupTestStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Physical Backup',
              style: context.font.bodyMedium,
            ),
            const Spacer(),
            Text(
              'Not Tested',
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.error,
              ),
            ),
          ],
        ),
        const Gap(15),
        Row(
          children: [
            Text(
              'Encrypted Vault',
              style: context.font.bodyMedium,
            ),
            const Spacer(),
            Text(
              'Tested',
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.inverseSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
