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
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

enum _ButtonPosition { first, last, middle }

class ActionCard extends StatelessWidget {
  const ActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ActionRow();
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.background,
        border: Border(
          bottom: BorderSide(color: context.appColors.outline, width: 1),
        ),
      ),
      child: Material(
        elevation: 2,
        shadowColor: context.appColors.onSurface.withValues(alpha: 0.5),
        color: context.appColors.transparent,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              _ActionButton(
                icon: Assets.icons.btc.path,
                label: 'Buy',
                onPressed: () {
                  if (Platform.isIOS) {
                    final isSuperuser =
                        context.read<SettingsCubit>().state.isSuperuser ??
                        false;
                    if (isSuperuser) {
                      context.pushNamed(BuyRoute.buy.name);
                    } else {
                      context.goNamed(ExchangeRoute.exchangeLanding.name);
                    }
                  } else {
                    context.pushNamed(BuyRoute.buy.name);
                  }
                },
                position: _ButtonPosition.first,
                disabled: false,
              ),
              const Gap(1),
              _ActionButton(
                icon: Assets.icons.dollar.path,
                label: 'Sell',
                onPressed: () {
                  if (Platform.isIOS) {
                    final isSuperuser =
                        context.read<SettingsCubit>().state.isSuperuser ??
                        false;
                    if (isSuperuser) {
                      context.pushNamed(SellRoute.sell.name);
                    } else {
                      context.goNamed(ExchangeRoute.exchangeLanding.name);
                    }
                  } else {
                    context.pushNamed(SellRoute.sell.name);
                  }
                },
                position: _ButtonPosition.middle,
                disabled: false,
              ),
              const Gap(1),
              _ActionButton(
                icon: Assets.icons.rightArrow.path,
                label: 'Pay',
                onPressed: () {
                  final notLoggedIn = context
                      .read<ExchangeCubit>()
                      .state
                      .notLoggedIn;

                  if (notLoggedIn) {
                    context.goNamed(ExchangeRoute.exchangeLanding.name);
                  } else {
                    if (Platform.isIOS) {
                      final isSuperuser =
                          context.read<SettingsCubit>().state.isSuperuser ??
                          false;
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
                position: _ButtonPosition.middle,
                disabled: false,
              ),
              const Gap(1),
              _ActionButton(
                icon: Assets.icons.swap.path,
                label: 'Transfer',
                onPressed: () {
                  context.pushNamed(SwapRoute.swap.name);
                },
                position: _ButtonPosition.last,
                disabled: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.position,
    required this.disabled,
  });

  final String icon;
  final String label;
  final Function onPressed;
  final _ButtonPosition position;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(2);
    final radius = BorderRadius.only(
      topLeft: position == _ButtonPosition.first ? r : Radius.zero,
      topRight: position == _ButtonPosition.last ? r : Radius.zero,
      bottomLeft: position == _ButtonPosition.first ? r : Radius.zero,
      bottomRight: position == _ButtonPosition.last ? r : Radius.zero,
    );

    return Expanded(
      child: InkWell(
        onTap: disabled ? null : () => onPressed(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: context.appColors.background,
            backgroundBlendMode: disabled ? .darken : null,
          ),
          child: Column(
            spacing: 8,
            mainAxisAlignment: .center,
            children: [
              Image.asset(
                icon,
                height: 24,
                width: 24,
                color: context.appColors.secondary,
              ),
              BBText(
                label,
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
