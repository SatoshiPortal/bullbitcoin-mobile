import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ExchangeLandingScreenV2 extends StatelessWidget {
  const ExchangeLandingScreenV2({super.key});

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
                context.loc.exchangeLandingRecommendedExchange,
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
                description: context.loc.exchangeLandingDisclaimerNotAvailable,
                tagColor: context.bull.primary,
                bgColor: context.bull.surface,
              ),
              const Gap(BullSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: BullButton.primary(
                  label: context.loc.exchangeGoToWebsiteButton,
                  onPressed: () async {
                    final url = Uri.parse('https://app.bullbitcoin.com');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
