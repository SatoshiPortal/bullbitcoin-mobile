import 'package:bb_mobile/core/themes/app_theme.dart';
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

class ExchangeSupportLoginScreen extends StatelessWidget {
  const ExchangeSupportLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.goNamed(WalletRoute.walletHome.name);
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          leading: BackButton(
            color: context.appColors.onSurface,
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
                      Assets.logos.bbLogoSmall.path,
                      width: 120,
                      height: 120,
                    ),
                    const Gap(16),
                    BBText(
                      context.loc.exchangeBrandName,
                      style: AppFonts.textTitleTheme.textStyle.copyWith(
                        color: context.appColors.primary,
                        fontSize: 64,
                      ),
                    ),
                    const Gap(12),
                    BBText(
                      context.loc.exchangeSupportLoginSubtitle,
                      style: context.font.headlineSmall?.copyWith(
                        color: context.appColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: context.appColors.surfaceContainer,
                  border: Border.all(
                    color: context.appColors.outline,
                    width: 0,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: BBText(
                  context.loc.exchangeSupportLoginAccessMessage,
                  style: context.font.bodyLarge?.copyWith(
                    color: context.appColors.onSurface,
                  ),
                ),
              ),
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: .start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.appColors.primary,
                      size: 20,
                    ),
                    const Gap(8),
                    Expanded(
                      child: BBText(
                        context.loc.exchangeSupportLoginAccountInfo,
                        style: context.font.bodySmall?.copyWith(
                          color: context.appColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(40),
              SizedBox(
                width: double.infinity,
                child: BBButton.big(
                  label: context.loc.exchangeLoginButton,
                  onPressed: () {
                    context.goNamed(ExchangeRoute.exchangeAuth.name);
                  },
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
              ),
              const Gap(32),
            ],
          ),
        ),
      ),
    );
  }
}
