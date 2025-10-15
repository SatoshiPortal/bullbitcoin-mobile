import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ExchangeLandingScreenV2 extends StatelessWidget {
  const ExchangeLandingScreenV2({super.key});

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
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Background image with geometric pattern
            Positioned.fill(
              child: Image.asset(
                Assets.backgrounds.bgLong.path,
                fit: BoxFit.cover,
              ),
            ),
            SingleChildScrollView(
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
                          'Recommended Bitcoin Exchange',
                          style: context.font.headlineSmall?.copyWith(
                            color: context.colour.onSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(32),
                  // Features List Box
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: context.colour.primary,
                        width: 0,
                      ),
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
                  // Disclaimer Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colour.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.colour.onSecondary,
                          size: 20,
                        ),
                        const Gap(8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BBText(
                                'Cryptocurrency exchange services are not available in the Bull Bitcoin mobile application.',
                                style: context.font.bodySmall?.copyWith(
                                  color: context.colour.onSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(40),
                  // Call-to-Action Button
                  SizedBox(
                    width: double.infinity,
                    child: BBButton.big(
                      label: 'Go to Bull Bitcoin exchange website',
                      onPressed: () async {
                        final Uri url = Uri.parse(
                          'https://app.bullbitcoin.com',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      bgColor: context.colour.primary,
                      textColor: context.colour.onSecondary,
                    ),
                  ),
                  const Gap(32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
