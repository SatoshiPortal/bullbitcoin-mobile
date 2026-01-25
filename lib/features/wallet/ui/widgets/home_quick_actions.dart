import 'dart:io';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/swap/ui/swap_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickActionItem(
            icon: Assets.icons.btc.path,
            label: 'Buy',
            onTap: () {
              if (Platform.isIOS) {
                final isSuperuser =
                    context.read<SettingsCubit>().state.isSuperuser ?? false;
                if (isSuperuser) {
                  context.pushNamed(BuyRoute.buy.name);
                } else {
                  context.goNamed(ExchangeRoute.exchangeLanding.name);
                }
              } else {
                context.pushNamed(BuyRoute.buy.name);
              }
            },
          ),
          _QuickActionItem(
            icon: Assets.icons.dollar.path,
            label: 'Sell',
            onTap: () {
              if (Platform.isIOS) {
                final isSuperuser =
                    context.read<SettingsCubit>().state.isSuperuser ?? false;
                if (isSuperuser) {
                  context.pushNamed(SellRoute.sell.name);
                } else {
                  context.goNamed(ExchangeRoute.exchangeLanding.name);
                }
              } else {
                context.pushNamed(SellRoute.sell.name);
              }
            },
          ),
          _QuickActionItem(
            icon: Assets.icons.rightArrow.path,
            label: 'Pay',
            onTap: () {
              final notLoggedIn =
                  context.read<ExchangeCubit>().state.notLoggedIn;
              if (notLoggedIn) {
                context.goNamed(ExchangeRoute.exchangeLanding.name);
              } else {
                if (Platform.isIOS) {
                  final isSuperuser =
                      context.read<SettingsCubit>().state.isSuperuser ?? false;
                  if (isSuperuser) {
                    context.pushNamed(PayRoute.pay.name);
                  } else {
                    context.goNamed(ExchangeRoute.exchangeLanding.name);
                  }
                } else {
                  context.pushNamed(PayRoute.pay.name);
                }
              }
            },
          ),
          _QuickActionItem(
            icon: Assets.icons.swap.path,
            label: 'Transfer',
            onTap: () {
              context.pushNamed(SwapRoute.swap.name);
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              icon,
              height: 24,
              width: 24,
              color: context.appColors.textMuted,
            ),
            const SizedBox(height: 6),
            BBText(
              label,
              style: context.font.labelSmall,
              color: context.appColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
