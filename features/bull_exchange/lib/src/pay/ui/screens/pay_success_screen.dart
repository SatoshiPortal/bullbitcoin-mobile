import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/pay/presentation/pay_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class PaySuccessScreen extends StatelessWidget {
  const PaySuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (PayBloc bloc) => bloc.state is PaySuccessState
          ? (bloc.state as PaySuccessState).payOrder
          : null,
    );

    return BullSuccessScreen(
      title: context.loc.payTitle,
      headline: context.loc.payCompleted,
      onClose: () => context.goNamed(BullExchangeNavigation.dashboardName),
      icon: Gif(
        image: AssetImage(context.read<ExchangePayinUi>().successAsset),
        autostart: Autostart.once,
        height: 100,
        width: 100,
      ),
      message: order == null
          ? null
          : Text(
              context.loc.payCompletedDescriptionDetails(
                order.payoutAmountToDisplay,
                order.recipientToDisplay ?? context.loc.payNotAvailable,
              ),
            ),
      actions: [
        if (order != null)
          BullButton.secondary(
            label: context.loc.payViewDetails,
            onPressed: () {
              final txId = order.payjoin?.txid;
              if (txId != null) {
                context.read<ExchangePayinUi>().openPayjoinTransaction(
                  context,
                  txId,
                );
              } else {
                context.read<ExchangePayinUi>().openOrder(
                  context,
                  order.orderId,
                  returnToExchange: true,
                );
              }
            },
          ),
      ],
    );
  }
}
