import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/buy/domain/buy_failure.dart';
import 'package:bull_exchange/src/buy/presentation/buy_bloc.dart';
import 'package:bull_exchange/src/buy/presentation/buy_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullSuccessScreen, Gap, BullTypographyX;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

class BuyAccelerateSuccessScreen extends StatelessWidget {
  final void Function(BuildContext) onClose;
  final void Function(BuildContext, String) openOrder;

  const BuyAccelerateSuccessScreen({
    super.key,
    required this.onClose,
    required this.openOrder,
  });

  @override
  Widget build(BuildContext context) {
    final buyOrder = context.select((BuyBloc bloc) => bloc.state.buyOrder);
    // This route builds its own bloc and refreshes the order on entry, so a
    // failed refresh is the reason "View details" is missing — say so instead
    // of leaving an empty slot.
    final BuyFailure? accelerateFailure = context.select(
      (BuyBloc bloc) => bloc.state.accelerateFailure,
    );

    return BullSuccessScreen(
      title: context.loc.buyConfirmTitle,
      headline: context.loc.buyBitcoinSent,
      message: Text(context.loc.buyThatWasFast),
      onClose: () => onClose(context),
      actions: [
        if (accelerateFailure != null) ...[
          Text(
            accelerateFailure.toTranslated(context),
            style: context.bullType.body.copyWith(
              color: context.appColors.error,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(16),
        ],
        if (buyOrder != null)
          BullButton.secondary(
            label: context.loc.buyViewDetails,
            onPressed: () {
              openOrder(context, buyOrder.orderId);
            },
          ),
      ],
    );
  }
}
