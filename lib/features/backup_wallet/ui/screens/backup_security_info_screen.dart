import 'package:bb_mobile/core/recoverbull/data/constants/backup_security_infos.dart';
import 'package:bb_mobile/features/backup_wallet/ui/backup_wallet_router.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart' show BBButton;
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackupSecurityInfoScreen extends StatelessWidget {
  final String backupOption;

  const BackupSecurityInfoScreen({
    super.key,
    required this.backupOption,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: backupOption.contains('encrypted-vault')
              ? "Encrypted Vault"
              : "Backup",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: backupOption.contains('encrypted-vault')
                    ? encryptedVaultSecurityInfo.length
                    : physicalBackupSecurityInfo.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.radio_button_checked,
                      color: context.colour.secondary,
                    ),
                    title: BBText(
                      backupOption.contains('encrypted-vault')
                          ? encryptedVaultSecurityInfo[index]
                          : physicalBackupSecurityInfo[index],
                      maxLines: 5,
                      style: context.font.labelMedium,
                    ),
                  );
                },
              ),
            ),
            BBButton.big(
              label: 'Start Backup',
              onPressed: backupOption.contains('encrypted-vault')
                  ? () => context.pushNamed(
                        BackupWalletSubroute.chooseBackupProvider.name,
                      )
                  //Todo: add physical backup screens
                  : () => context.pushNamed(
                        BackupWalletSubroute.physical.name,
                      ),
              bgColor: context.colour.secondary,
              textColor: context.colour.onSecondary,
            ),
            const Gap(12),
          ],
        ),
      ),
    );
  }
}
