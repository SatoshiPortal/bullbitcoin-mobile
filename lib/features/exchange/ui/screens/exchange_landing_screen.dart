import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ExchangeLandingScreen extends StatelessWidget {
  const ExchangeLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        // Navigate to the wallet home screen when the user wants to exit the
        // exchange landing screen.
        context.goNamed(WalletRoute.walletHome.name);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        appBar: AppBar(
          leading: BackButton(
            color: Theme.of(context).colorScheme.onSecondary,
            onPressed: () => context.goNamed(WalletRoute.walletHome.name),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Gap(32),
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      Assets.logos.bbLogoWhite.path,
                      width: 120,
                      height: 120,
                    ),
                    const Gap(16),
                    BBText(
                      context.loc.exchangeBrandName,
                      style: AppFonts.textTitleTheme.textStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontSize: 64,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeLandingConnectAccount,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BBText(
                      context.loc.exchangeFeatureSelfCustody,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeFeatureDcaOrders,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeFeatureSellBitcoin,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeFeatureBankTransfers,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeFeatureCustomerSupport,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeFeatureUnifiedHistory,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: BBText(
                  context.loc.exchangeLandingDisclaimerLegal,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ),
              const Gap(40),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: BBButton.big(
                      label: context.loc.exchangeLoginButton,
                      onPressed: () {
                        context.goNamed(ExchangeRoute.exchangeAuth.name);
                      },
                      bgColor: Theme.of(context).colorScheme.primary,
                      textColor: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                ],
              ),
              const Gap(32),
            ],
          ),
        ),
      ),
    );
  }
}
