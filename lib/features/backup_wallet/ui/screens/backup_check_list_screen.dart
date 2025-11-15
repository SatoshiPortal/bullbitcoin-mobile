import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackCheckListScreen extends StatelessWidget {
  const BackCheckListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final defaultWallet = context.select(
      (WalletBloc cubit) => cubit.state.wallets.firstWhereOrNull(
        (wallet) => wallet.isDefault && wallet.network.isBitcoin,
      ),
    );
    final lastPhysicalBackup = defaultWallet?.latestPhysicalBackup;

    final instructions = backupInstructions(context);
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: context.loc.backupWalletBestPracticesTitle,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lastPhysicalBackup != null) ...[
                const Gap(8),
                BBText(
                  '${context.loc.backupWalletLastBackupTest}${lastPhysicalBackup.toString().substring(0, 19)}',
                  style: context.font.bodyMedium,
                ),
              ],
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
                label: context.loc.backupWalletBackupButton,
              ),
              const Gap(60),
            ],
          ),
        ),
      ),
    );
  }

  List<String> backupInstructions(BuildContext context) {
    return [
      context.loc.backupWalletInstructionLoseBackup,
      context.loc.backupWalletInstructionLosePhone,
      context.loc.backupWalletInstructionSecurityRisk,
      context.loc.backupWalletInstructionNoDigitalCopies,
      context.loc.backupWalletInstructionNoPassphrase,
    ];
  }
}
