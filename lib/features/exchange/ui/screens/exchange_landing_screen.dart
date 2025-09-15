import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
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
        backgroundColor: context.colour.secondary,
        appBar: AppBar(
          leading: BackButton(
            color: context.colour.onSecondary,
            onPressed: () => context.goNamed(WalletRoute.walletHome.name),
          ),
        ),
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
                      'BULL BITCOIN',
                      style: AppFonts.textTitleTheme.textStyle.copyWith(
                        color: context.colour.onSecondary,
                        fontSize: 64,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      'Connect your Bull Bitcoin exchange account',
                      style: context.font.headlineSmall?.copyWith(
                        color: context.colour.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: context.colour.primary, width: 0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BBText(
                      '• Buy Bitcoin straight to self-custody',
                      style: context.font.bodyLarge?.copyWith(
                        color: context.colour.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      '• DCA, Limit orders and Auto-buy',
                      style: context.font.bodyLarge?.copyWith(
                        color: context.colour.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      '• Sell Bitcoin, get paid with Bitcoin',
                      style: context.font.bodyLarge?.copyWith(
                        color: context.colour.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      '• Send bank transfers and pay bills',
                      style: context.font.bodyLarge?.copyWith(
                        color: context.colour.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      '• Chat with customer support',
                      style: context.font.bodyLarge?.copyWith(
                        color: context.colour.onSecondary,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      '• Unified transaction history',
                      style: context.font.bodyLarge?.copyWith(
                        color: context.colour.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colour.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: BBText(
                  'Access to exchange services will be restricted to countries where Bull Bitcoin can legally operate and may require KYC.',
                  style: context.font.bodySmall?.copyWith(
                    color: context.colour.onSecondary,
                  ),
                ),
              ),
              const Gap(40),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: BBButton.big(
                      label: 'Login Or Sign up',
                      onPressed: () {
                        context.goNamed(ExchangeRoute.exchangeAuth.name);
                      },
                      bgColor: context.colour.primary,
                      textColor: context.colour.onSecondary,
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
