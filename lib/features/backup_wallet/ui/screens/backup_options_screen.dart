import 'dart:ui';

import 'package:bb_mobile/features/backup_wallet/ui/backup_wallet_router.dart';
import 'package:bb_mobile/features/backup_wallet/ui/widgets/how_to_decide.dart'
    show HowToDecideSheetBackupOption;
import 'package:bb_mobile/features/backup_wallet/ui/widgets/option_tag.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackupOptionsScreen extends StatefulWidget {
  const BackupOptionsScreen({super.key});

  @override
  State<BackupOptionsScreen> createState() => _BackupOptionsScreenState();
}

class _BackupOptionsScreenState extends State<BackupOptionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: 'Backup your wallet',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(20),
              BBText(
                'Without a backup, you will eventually lose access to your money. It is critically important to do a backup.',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: context.font.bodyLarge,
              ),
              const Gap(16),
              BackupOptionCard(
                icon: Image.asset(
                  'assets/encrypted_vault.png',
                  width: 36,
                  height: 45,
                  fit: BoxFit.cover,
                ),
                title: 'Encrypted vault',
                description:
                    'Anonymous backup with strong encryption using your cloud.',
                tag: 'Easy and simple (1 minute)',
                onTap: () => context.pushNamed(
                  BackupWalletSubroute.securityInfo.name,
                  extra: 'encrypted-vault',
                ),
              ),
              const Gap(16),
              BackupOptionCard(
                icon: Image.asset(
                  'assets/physical_backup.png',
                  width: 36,
                  height: 45,
                  fit: BoxFit.cover,
                ),
                title: 'Physical backup',
                description:
                    'Write down 12 words on a piece of paper. Keep them safe and make sure not to lose them.',
                tag: 'Trustless (take your time)',
                onTap: () => context.pushNamed(
                  BackupWalletSubroute.securityInfo.name,
                  extra: 'physical-backup',
                ),
              ),
              const Gap(16),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) {
                      return Stack(
                        children: [
                          // Blurred Background ONLY on the Top
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                child: Container(
                                  width: double.infinity,
                                  height: MediaQuery.of(context).size.height *
                                      0.25, // Blur only 40% of the screen
                                  color: context.colour.secondary
                                      .withAlpha(25), // 0.10 opacity ≈ alpha 25
                                ),
                              ),
                            ),
                          ),

                          // Bottom Sheet Content (Covers only 60% of the screen)
                          const Align(
                            alignment: Alignment.bottomCenter,
                            child: HowToDecideSheetBackupOption(),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: BBText(
                  "How to decide?",
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

class BackupOptionCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;
  final String tag;
  final VoidCallback onTap;

  const BackupOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: context.colour.surface),
          boxShadow: [
            BoxShadow(
              color: context.colour.surface,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    height: 45,
                    child: icon,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BBText(
                          title,
                          style: context.font.headlineMedium,
                        ),
                        const Gap(10),
                        BBText(
                          description,
                          style: context.font.bodySmall?.copyWith(
                            color: context.colour.outline,
                          ),
                          maxLines: 3,
                        ),
                        const Gap(10),
                        OptionsTag(text: tag),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: Icon(Icons.arrow_forward, color: context.colour.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
