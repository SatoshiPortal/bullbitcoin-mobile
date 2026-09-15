import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/backup_option_card.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/how_to_decide.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_routes.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_routes.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';

class BackupOptionsScreen extends StatelessWidget {
  final BackupSettingsFlow flow;
  final bool hasPhysicalBackup;
  final bool hasEncryptedBackup;

  const BackupOptionsScreen({
    super.key,
    required this.flow,
    this.hasPhysicalBackup = false,
    this.hasEncryptedBackup = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (flow) {
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
            crossAxisAlignment: .start,
            children: [
              const Gap(20),
              BBText(
                context.loc.backupWalletImportanceWarning,
                textAlign: .center,
                style: context.font.bodyLarge,
                maxLines: 5,
              ),
              const Gap(16),
              if (flow == BackupSettingsFlow.backup || hasEncryptedBackup)
                BackupOptionCard(
                  icon: Image.asset(
                    Assets.misc.encryptedVault.path,
                    width: 32,
                    height: 40,
                    fit: .contain,
                  ),
                  title: context.loc.backupWalletEncryptedVaultTitle,
                  description:
                      context.loc.backupWalletEncryptedVaultDescription,
                  tags: [
                    context.loc.backupWalletEncryptedVaultTag,
                    context.loc.backupWalletEncryptedVaultUsesTorTag,
                  ],
                  onTap: () => context.pushNamed(
                    RecoverBullRoute.recoverbullFlows.name,
                    extra: RecoverBullFlowsExtra(
                      flow: switch (flow) {
                        BackupSettingsFlow.backup =>
                          RecoverBullFlow.secureVault,
                        BackupSettingsFlow.test => RecoverBullFlow.testVault,
                      },
                      vault: null,
                    ),
                  ),
                ),
              if (flow == BackupSettingsFlow.backup || hasEncryptedBackup)
                const Gap(16),

              if (flow == BackupSettingsFlow.backup || hasPhysicalBackup)
                BackupOptionCard(
                  icon: Image.asset(
                    Assets.misc.physicalBackup.path,
                    width: 32,
                    height: 40,
                    fit: .contain,
                  ),
                  title: context.loc.backupWalletPhysicalBackupTitle,
                  description:
                      context.loc.backupWalletPhysicalBackupDescription,
                  tags: [context.loc.backupWalletPhysicalBackupTag],
                  onTap: () {
                    context.pushNamed(
                      TestWalletBackupRoute.testPhysicalBackupFlow.name,
                      extra: switch (flow) {
                        BackupSettingsFlow.backup =>
                          TestPhysicalBackupFlow.backup,
                        BackupSettingsFlow.test =>
                          TestPhysicalBackupFlow.verify,
                      },
                    );
                  },
                ),
              if (flow == BackupSettingsFlow.backup || hasPhysicalBackup)
                const Gap(16),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () {
                    BlurredBottomSheet.show(
                      context: context,
                      child: const HowToDecideBackupOption(),
                    );
                  },
                  child: BBText(
                    context.loc.backupWalletHowToDecide,
                    style: context.font.headlineLarge?.copyWith(
                      color: context.appColors.primary,
                    ),
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
