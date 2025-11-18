import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/backup_option_card.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/how_to_decide.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackupOptionsScreen extends StatefulWidget {
  final BackupSettingsFlow flow;
  const BackupOptionsScreen({super.key, required this.flow});

  @override
  State<BackupOptionsScreen> createState() => _BackupOptionsScreenState();
}

class _BackupOptionsScreenState extends State<BackupOptionsScreen> {
  @override
  Widget build(BuildContext context) {
    final title = switch (widget.flow) {
      BackupSettingsFlow.backup => context.loc.backupWalletTitle,
      BackupSettingsFlow.test => context.loc.testBackupTitle,
    };
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(onBack: () => context.pop(), title: title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(20),
              BBText(
                context.loc.backupWalletImportanceWarning,
                textAlign: TextAlign.center,
                style: context.font.bodyLarge,
                maxLines: 5,
              ),
              const Gap(16),
              BackupOptionCard(
                icon: Image.asset(
                  Assets.misc.encryptedVault.path,
                  width: 36,
                  height: 45,
                  fit: BoxFit.cover,
                ),
                title: context.loc.backupWalletEncryptedVaultTitle,
                description: context.loc.backupWalletEncryptedVaultDescription,
                tag: context.loc.backupWalletEncryptedVaultTag,
                onTap:
                    () => {
                      context.pushNamed(
                        RecoverBullRoute.recoverbullFlows.name,
                        extra: RecoverBullFlowsExtra(
                          flow: RecoverBullFlow.secureVault,
                          vault: null,
                        ),
                      ),
                    },
              ),
              const Gap(16),

              BackupOptionCard(
                icon: Image.asset(
                  Assets.misc.physicalBackup.path,
                  width: 36,
                  height: 45,
                  fit: BoxFit.cover,
                ),
                title: context.loc.backupWalletPhysicalBackupTitle,
                description: context.loc.backupWalletPhysicalBackupDescription,
                tag: context.loc.backupWalletPhysicalBackupTag,
                onTap: () {
                  context.pushNamed(
                    TestWalletBackupRoute.testPhysicalBackupFlow.name,
                    extra: switch (widget.flow) {
                      BackupSettingsFlow.backup =>
                        TestPhysicalBackupFlow.backup,
                      BackupSettingsFlow.test => TestPhysicalBackupFlow.verify,
                    },
                  );
                },
              ),
              const Gap(16),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const HowToDecideBackupOption(),
                  );
                },
                child: BBText(
                  context.loc.backupWalletHowToDecide,
                  style: context.font.headlineLarge?.copyWith(
                    color: context.colour.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
