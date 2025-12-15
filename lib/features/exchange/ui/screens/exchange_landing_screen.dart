import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/themes/fonts.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
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
        backgroundColor: context.appColors.secondary,
        appBar: AppBar(
          leading: BackButton(
            color: context.appColors.onSecondary,
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
                        color: context.appColors.onSecondary,
                        fontSize: 64,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeLandingConnectAccount,
                      style: context.font.headlineSmall?.copyWith(
                        color: context.appColors.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: context.appColors.primary,
                    width: 0,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    BBText(
                      context.loc.exchangeFeatureSelfCustody,
                      style: context.font.bodyLarge?.copyWith(
                        color: context.appColors.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeFeatureDcaOrders,
                      style: context.font.bodyLarge?.copyWith(
                        color: context.appColors.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeFeatureSellBitcoin,
                      style: context.font.bodyLarge?.copyWith(
                        color: context.appColors.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeFeatureBankTransfers,
                      style: context.font.bodyLarge?.copyWith(
                        color: context.appColors.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeFeatureCustomerSupport,
                      style: context.font.bodyLarge?.copyWith(
                        color: context.appColors.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeFeatureUnifiedHistory,
                      style: context.font.bodyLarge?.copyWith(
                        color: context.appColors.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: BBText(
                  context.loc.exchangeLandingDisclaimerLegal,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.onSecondary,
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
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onSecondary,
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
