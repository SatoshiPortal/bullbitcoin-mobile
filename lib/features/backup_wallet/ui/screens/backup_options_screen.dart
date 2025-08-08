import 'dart:ui';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/backup_option_card.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/backup_wallet/ui/backup_wallet_router.dart';
import 'package:bb_mobile/features/backup_wallet/ui/widgets/how_to_decide.dart';
import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      body: BlocProvider(
        create: (context) => locator<KeyServerCubit>(),
        child: BlocBuilder<KeyServerCubit, KeyServerState>(
          builder: (context, state) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(20),
                    BBText(
                      'Without a backup, you will eventually lose access to your money. It is critically important to do a backup.',
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
                      title: 'Encrypted vault',
                      description:
                          'Anonymous backup with strong encryption using your cloud.',
                      tag: 'Easy and simple (1 minute)',
                      onTap:
                          () => {
                            context.read<KeyServerCubit>().checkConnection(),
                            context.pushNamed(
                              BackupWalletSubroute.chooseBackupProvider.name,
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
                      title: 'Physical backup',
                      description:
                          'Write down 12 words on a piece of paper. Keep them safe and make sure not to lose them.',
                      tag: 'Trustless (take your time)',
                      onTap:
                          () => context.pushNamed(
                            BackupWalletSubroute.physicalCheckList.name,
                          ),
                    ),
                    const Gap(16),
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          constraints: const BoxConstraints(
                            maxWidth: double.infinity,
                          ),
                          backgroundColor: Colors.transparent,
                          builder: (context) {
                            return Stack(
                              children: [
                                // Blurred Background ONLY on the Top
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 6,
                                        sigmaY: 6,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        height:
                                            MediaQuery.of(context).size.height *
                                            0.25, // Blur only 40% of the screen
                                        color: context.colour.secondary
                                            .withAlpha(
                                              25,
                                            ), // 0.10 opacity ≈ alpha 25
                                      ),
                                    ),
                                  ),
                                ),

                                // Bottom Sheet Content (Covers only 60% of the screen)
                                const Align(
                                  alignment: Alignment.bottomCenter,
                                  child: HowToDecideBackupOption(),
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
            );
          },
        ),
      ),
    );
  }
}
