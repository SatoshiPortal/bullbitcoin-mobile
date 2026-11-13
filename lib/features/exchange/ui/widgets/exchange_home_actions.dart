import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show BullIcons, BullToolButton;
import 'package:flutter/material.dart';

enum ExchangeHomeAction { buy, sell, pay, transfer }

class ExchangeHomeActions extends StatelessWidget {
  const ExchangeHomeActions({required this.onAction, super.key});

  final void Function(ExchangeHomeAction) onAction;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        ExchangeHomeAction.buy,
        context.loc.homeActionBuy,
        BullIcons.shoppingCart,
      ),
      (ExchangeHomeAction.sell, context.loc.homeActionSell, BullIcons.sell),
      (ExchangeHomeAction.pay, context.loc.homeActionPay, BullIcons.payments),
      (
        ExchangeHomeAction.transfer,
        context.loc.homeActionTransfer,
        BullIcons.swapHoriz,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.background,
        border: Border(bottom: BorderSide(color: context.appColors.outline)),
      ),
      child: Material(
        elevation: 2,
        shadowColor: context.appColors.onSurface.withValues(alpha: 0.5),
        color: context.appColors.transparent,
        child: Row(
          children: [
            for (final (action, label, icon) in actions)
              Expanded(
                child: BullToolButton(
                  label: label,
                  icon: icon,
                  onPressed: () => onAction(action),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
