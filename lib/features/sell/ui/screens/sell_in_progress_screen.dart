import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart';

class SellInProgressScreen extends StatelessWidget {
  const SellInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation
      },
      child: BullPage(
        topBar: BullTopBar(title: context.loc.sellTitle),
        safeArea: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: .center,
              crossAxisAlignment: .center,
              children: [
                const Spacer(),
                Column(
                  children: [
                    Gif(
                      autostart: Autostart.loop,
                      height: 123,
                      image: AssetImage(Assets.animations.cubesLoading.path),
                    ),
                    Text(
                      context.loc.sellInProgress,
                      style: context.font.headlineLarge?.copyWith(
                        color: context.appColors.outlineVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                BullButton.primary(
                  label: context.loc.sellGoHome,
                  onPressed: () {
                    context.goNamed(ExchangeRoute.exchangeHome.name);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
