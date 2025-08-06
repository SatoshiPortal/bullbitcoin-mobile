import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackCheckListScreen extends StatelessWidget {
  const BackCheckListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final instructions = backupInstructions();
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: 'Backup best practices',
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(8),
              const Gap(24),
              for (final i in instructions) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(8),
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Icon(Icons.circle, color: Colors.black, size: 20),
                    ),
                    const Gap(8),
                    Expanded(
                      child: BBText(
                        i,
                        style: context.font.bodyMedium,
                        maxLines: 5,
                      ),
                    ),
                  ],
                ),
                const Gap(16),
              ],
              const Gap(54),
              BBButton.big(
                textColor: context.colour.onSecondary,
                bgColor: context.colour.secondary,
                onPressed:
                    () => context.pushNamed(
                      TestWalletBackupSubroute.testPhysicalBackup.name,
                    ),
                label: 'Backup',
              ),
              const Gap(60),
            ],
          ),
        ),
      ),
    );
  }

  List<String> backupInstructions() {
    return [
      'If you lose your 12 word backup, you will not be able to recover access to the Bitcoin Wallet.',
      'Without a backup, if you lose or break your phone, or if you uninstall the Bull Bitcoin app, your bitcoins will be lost forever.',
      'Anybody with access to your 12 word backup can steal your bitcoins. Hide it well.',
      'Do not make digital copies of your backup. Write it down on a piece of paper, or engraved in metal.',
      'Your backup is not protected by passphrase. Add a passphrase to your backup later by creating a new wallet.',
      // (No passphrase)
      // If you lose your 12 word backup, you will not be able to recover access to the Bitcoin Wallet.
      // Without a backup, if you lose or break your phone, or if you uninstall the Bull Bitcoin app, your bitcoins will be lost forever.
      // Anybody with access to your 12 word backup can steal your bitcoins. Hide it well.
      // Do not make digital copies of your backup. Write it down on a piece of paper, or engraved in metal.
      // Your backup is not protected by passphrase. Add a passphrase to your backup later by creating a new wallet.
    ];
  }
}
