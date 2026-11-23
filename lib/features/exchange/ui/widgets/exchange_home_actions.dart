import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullIcons, BullQuickAction, BullQuickActionBar;
import 'package:material_ui/material_ui.dart';

enum ExchangeHomeAction { buy, sell, pay, transfer }

/// The exchange's shortcuts, the same card as Home's quick actions, straddling
/// the bottom edge of the dark balance area.
class ExchangeHomeActions extends StatelessWidget {
  const ExchangeHomeActions({required this.onAction, super.key});

  final void Function(ExchangeHomeAction) onAction;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        ExchangeHomeAction.buy,
        context.loc.homeActionBuy,
        BullIcons.addCircleOutline,
      ),
      (ExchangeHomeAction.sell, context.loc.homeActionSell, BullIcons.sell),
      (
        ExchangeHomeAction.pay,
        context.loc.homeActionPay,
        BullIcons.receiptLong,
      ),
      (
        ExchangeHomeAction.transfer,
        context.loc.homeActionTransfer,
        BullIcons.swapHoriz,
      ),
    ];
    return BullQuickActionBar(
      children: [
        for (final (action, label, icon) in actions)
          BullQuickAction(
            label: label,
            icon: icon,
            onPressed: () => onAction(action),
          ),
      ],
    );
  }
}
