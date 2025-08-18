import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/backup_option_card.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TestBackupOptionsScreen extends StatefulWidget {
  const TestBackupOptionsScreen({super.key});

  @override
  State<TestBackupOptionsScreen> createState() =>
      _TestBackupOptionsScreenState();
}

class _TestBackupOptionsScreenState extends State<TestBackupOptionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: 'Test your wallet',
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
                      maxLines: 5,
                      textAlign: TextAlign.center,
                      style: context.font.bodyLarge,
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
                              TestWalletBackupSubroute
                                  .chooseBackupTestProvider
                                  .name,
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
                            TestWalletBackupSubroute.testPhysicalBackup.name,
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
