import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/recovered_wallet_cards.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class OnboardingRecoverySuccess extends StatelessWidget {
  const OnboardingRecoverySuccess({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Recovered Wallets'),
        forceMaterialTransparency: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BBText(
              'The following wallets were successfully recovered',
              style: context.font.bodySmall,
            ),
            const Gap(16),
            const Expanded(child: RecoveredWalletCards()),
            const Gap(16),
            BBButton.big(
              label: 'Try Another',
              bgColor: Colors.transparent,
              outlined: true,
              textColor: context.colour.secondary,
              onPressed: () {
                context.goNamed(OnboardingRoute.chooseRecoverProvider.name);
              },
            ),
            const Gap(8),
            BBButton.big(
              label: 'Done',
              bgColor: context.colour.secondary,
              textColor: context.colour.onPrimary,
              onPressed: () {
                context.goNamed(WalletRoute.walletHome.name);
              },
            ),
          ],
        ),
      ),
    );
  }
}
