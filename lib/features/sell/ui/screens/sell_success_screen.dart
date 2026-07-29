import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/success_screen_scaffold.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SellSuccessScreen extends StatelessWidget {
  const SellSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final successState = context.select(
      (SellBloc bloc) => bloc.state is SellSuccessState
          ? bloc.state as SellSuccessState
          : null,
    );
    final order = successState?.sellOrder;

    String? amountLine;
    if (successState != null && order != null) {
      final formattedPayinAmount = successState.bitcoinUnit == BitcoinUnit.sats
          ? FormatAmount.sats(ConvertAmount.btcToSats(order.payinAmount))
          : FormatAmount.btc(order.payinAmount);
      amountLine = context.loc.sellYouSold(
        formattedPayinAmount,
        FormatAmount.fiat(order.payoutAmount, order.payoutCurrency),
      );
    }

    return SuccessScreenScaffold(
      title: context.loc.sellTitle,
      headline: context.loc.sellOrderCompleted,
      // Same exit as buy: back to the wallet home, including on a back gesture.
      onClose: () => context.goNamed(WalletRoute.walletHome.name),
      amountLine: amountLine,
      message: order != null && order.isBalancePayout
          ? Text(context.loc.sellBalanceWillBeCredited)
          : null,
      actions: [
        if (order != null)
          BBButton.big(
            label: context.loc.sellViewDetailsButton,
            onPressed: () {
              context.pushNamed(
                TransactionsRoute.orderTransactionDetails.name,
                pathParameters: {'orderId': order.orderId},
                queryParameters: {'returnToExchange': 'true'},
              );
            },
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
      ],
    );
  }
}
