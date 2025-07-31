import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class SellInProgressScreen extends StatelessWidget {
  const SellInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sell Bitcoin'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                      'Sell in progress...',
                      style: context.font.headlineLarge?.copyWith(
                        color: context.colour.outlineVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                BBButton.big(
                  label: 'Go home',
                  onPressed: () {
                    context.goNamed(ExchangeRoute.exchangeHome.name);
                  },
                  bgColor: context.colour.secondary,
                  textColor: context.colour.onSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
