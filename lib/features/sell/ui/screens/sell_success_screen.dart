import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SellSuccessScreen extends StatefulWidget {
  const SellSuccessScreen({super.key});

  @override
  State<SellSuccessScreen> createState() => _SellSuccessScreenState();
}

class _SellSuccessScreenState extends State<SellSuccessScreen> {
  Timer? _payjoinRefreshTimer;

  @override
  void initState() {
    super.initState();
    _payjoinRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final bloc = context.read<SellBloc>();
      final state = bloc.state;
      if (state is! SellSuccessState ||
          !state.sellOrder.payjoinOutcome.isOngoing) {
        _payjoinRefreshTimer?.cancel();
        return;
      }
      bloc.add(const SellEvent.pollOrderStatus());
    });
  }

  @override
  void dispose() {
    _payjoinRefreshTimer?.cancel();
    super.dispose();
  }

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

    final showBalanceMessage = order?.isBalancePayout == true;
    final showPayjoinStatus =
        order != null && order.payjoinOutcome != OrderPayjoinOutcome.none;

    return BullSuccessScreen(
      title: context.loc.sellTitle,
      headline: context.loc.sellOrderCompleted,
      onClose: () => context.goNamed(WalletRoute.walletHome.name),
      amountLine: amountLine,
      message: order == null || (!showBalanceMessage && !showPayjoinStatus)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBalanceMessage)
                  Text(context.loc.sellBalanceWillBeCredited),
                if (showBalanceMessage && showPayjoinStatus)
                  const SizedBox(height: 10),
                if (showPayjoinStatus)
                  BullAsyncStatus(
                    state: switch (order.payjoinOutcome) {
                      OrderPayjoinOutcome.none => BullAsyncStatusState.hidden,
                      OrderPayjoinOutcome.inProgress =>
                        BullAsyncStatusState.inProgress,
                      OrderPayjoinOutcome.succeeded =>
                        BullAsyncStatusState.succeeded,
                      OrderPayjoinOutcome.plainSend =>
                        BullAsyncStatusState.fallback,
                    },
                    inProgressLabel: context.loc.payjoinInProgress,
                    succeededLabel: context.loc.payjoinViaPayjoin,
                    fallbackLabel: context.loc.payjoinViaRegularSend,
                    inProgressColor: context.appColors.secondary,
                    successColor: context.appColors.success,
                    textStyle: context.font.bodyMedium,
                  ),
              ],
            ),
      actions: [
        if (order != null)
          BBButton.big(
            label: context.loc.sellViewDetailsButton,
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
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
      ],
    );
  }
}
