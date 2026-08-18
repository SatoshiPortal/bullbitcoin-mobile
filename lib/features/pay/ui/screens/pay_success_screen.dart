import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
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
      onClose: () => context.goNamed(ExchangeRoute.exchangeHome.name),
      icon: Gif(
        image: AssetImage(Assets.animations.successTick.path),
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
          BullButton.primary(
            label: context.loc.payViewDetails,
            onPressed: () {
              final txId = order.payjoin?.txid;
              if (txId != null) {
                context.pushNamed(
                  TransactionsRoute.payjoinTransactionDetailsByTxId.name,
                  pathParameters: {'txId': txId},
                  queryParameters: {'returnToExchange': 'true'},
                );
              } else {
                context.pushNamed(
                  TransactionsRoute.orderTransactionDetails.name,
                  pathParameters: {'orderId': order.orderId},
                  queryParameters: {'returnToExchange': 'true'},
                );
              }
            },
          ),
      ],
    );
  }
}
