import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExchangeLandingScreen extends StatelessWidget {
  const ExchangeLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed(WalletRoute.walletHome.name);
      },
      child: BullPage(
        padding: EdgeInsets.zero,
        topBar: BullTopBar(
          title: context.loc.exchangeBrandName,
          onBack: () => context.goNamed(WalletRoute.walletHome.name),
        ),
        bottomBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SafeArea(
            top: false,
            child: BullButton.primary(
              label: context.loc.exchangeLoginButton,
              onPressed: () => context.goNamed(ExchangeRoute.exchangeAuth.name),
            ),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            children: [
              const Gap(BullSpacing.lg),
              Image.asset(
                Assets.logos.bbLogoSmall.path,
                width: 120,
                height: 120,
              ),
              const Gap(BullSpacing.md),
              BullText(
                context.loc.exchangeBrandName,
                style: context.bullText.displayLarge,
                color: context.bull.primary,
              ),
              const Gap(BullSpacing.sm),
              BullText(
                context.loc.exchangeLandingConnectAccount,
                style: context.bullText.headlineSmall,
              ),
              const Gap(BullSpacing.lg),
              BullBorderedTile(
                padding: const EdgeInsets.all(BullSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final text in [
                      context.loc.exchangeFeatureSelfCustody,
                      context.loc.exchangeFeatureDcaOrders,
                      context.loc.exchangeFeatureSellBitcoin,
                      context.loc.exchangeFeatureBankTransfers,
                      context.loc.exchangeFeatureCustomerSupport,
                      context.loc.exchangeFeatureUnifiedHistory,
                    ]) ...[
                      BullText(text, style: context.bullText.bodyLarge),
                      const Gap(BullSpacing.sm),
                    ],
                  ],
                ),
              ),
              const Gap(BullSpacing.sm),
              BullInfoCard(
                description: context.loc.exchangeLandingDisclaimerLegal,
                tagColor: context.bull.warning,
                bgColor: context.bull.warningContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
