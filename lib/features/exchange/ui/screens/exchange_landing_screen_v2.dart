import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/exchange_support_chat/ui/exchange_support_chat_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
        backgroundColor: context.appColors.secondary,
        appBar: AppBar(
          leading: BackButton(
            color: context.appColors.onSecondary,
            onPressed: () => context.goNamed(WalletRoute.walletHome.name),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: context.appColors.onSecondary,
                size: 24,
              ),
              onPressed: () {
                final notLoggedIn =
                    context.read<ExchangeCubit>().state.notLoggedIn;
                if (notLoggedIn) {
                  _showLoginPromptDialog(context);
                } else {
                  context.pushNamed(ExchangeSupportChatRoute.supportChat.name);
                }
              },
            ),
          ],
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Background image with geometric pattern
            Positioned.fill(
              child: Image.asset(
                Assets.backgrounds.bgLong.path,
                fit: .cover,
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
                          context.loc.exchangeBrandName,
                          style: AppFonts.textTitleTheme.textStyle.copyWith(
                            color: context.appColors.onSecondary,
                            fontSize: 64,
                          ),
                        ),
                        const Gap(12),
                        BBText(
                          context.loc.exchangeLandingRecommendedExchange,
                          style: context.font.headlineSmall?.copyWith(
                            color: context.appColors.onSecondary,
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
                  // Disclaimer Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.appColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: .start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.appColors.onSecondary,
                          size: 20,
                        ),
                        const Gap(8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              BBText(
                                context
                                    .loc
                                    .exchangeLandingDisclaimerNotAvailable,
                                style: context.font.bodySmall?.copyWith(
                                  color: context.appColors.onSecondary,
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
                      label: context.loc.exchangeGoToWebsiteButton,
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
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onSecondary,
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

  void _showLoginPromptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: BBText(
          context.loc.exchangeSupportChatTitle,
          style: context.font.headlineSmall,
        ),
        content: BBText(
          context.loc.exchangeLandingLoginToUseSupport,
          style: context.font.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: BBText(
              context.loc.cancelButton,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.goNamed(ExchangeRoute.exchangeAuth.name);
            },
            child: BBText(
              context.loc.exchangeLoginButton,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
