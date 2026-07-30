import 'dart:async';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/buy/ui/widgets/accelerate_transaction_list_tile.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart';

class BuySuccessScreen extends StatefulWidget {
  const BuySuccessScreen({super.key});

  @override
  State<BuySuccessScreen> createState() => _BuySuccessScreenState();
}

class _BuySuccessScreenState extends State<BuySuccessScreen> {
  Timer? _payjoinRefreshTimer;

  @override
  void initState() {
    super.initState();
    _payjoinRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final bloc = context.read<BuyBloc>();
      final state = bloc.state;
      if (state.buyOrder?.payjoinOutcome.isOngoing != true) {
        _payjoinRefreshTimer?.cancel();
        return;
      }
      if (!state.isRefreshingOrder) bloc.add(const BuyEvent.refreshOrder());
    });
  }

  @override
  void dispose() {
    _payjoinRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyOrder = context.select((BuyBloc bloc) => bloc.state.buyOrder!);
    final payoutAmountBtc = buyOrder.payoutAmount;
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit,
    );
    final payoutAmountSat = ConvertAmount.btcToSats(
      payoutAmountBtc,
    ); // Convert sats to BTC
    final formattedPayOutAmount = bitcoinUnit == BitcoinUnit.sats
        ? FormatAmount.sats(payoutAmountSat)
        : FormatAmount.btc(buyOrder.payoutAmount);
    final formattedPayInAmount = FormatAmount.fiat(
      buyOrder.payinAmount,
      buyOrder.payinCurrency,
    );
    final payoutTime = buyOrder.scheduledPayoutTime;

    return BullSuccessScreen(
      title: context.loc.buyConfirmTitle,
      headline: context.loc.buyYouBought(
        formattedPayOutAmount,
        formattedPayInAmount,
      ),
      onClose: () => context.goNamed(WalletRoute.walletHome.name),
      message: Column(
        mainAxisSize: .min,
        children: [
          // The payout may still be negotiating a payjoin. Keep the outcome
          // visible without requiring the customer to open transaction details.
          BullAsyncStatus(
            state: switch (buyOrder.payjoinOutcome) {
              OrderPayjoinOutcome.none => BullAsyncStatusState.hidden,
              OrderPayjoinOutcome.inProgress => BullAsyncStatusState.inProgress,
              OrderPayjoinOutcome.succeeded => BullAsyncStatusState.succeeded,
              OrderPayjoinOutcome.plainSend => BullAsyncStatusState.fallback,
            },
            inProgressLabel: context.loc.payjoinInProgress,
            succeededLabel: context.loc.payjoinSucceeded,
            fallbackLabel: context.loc.payjoinBuyRegularSend,
            inProgressColor: context.appColors.secondary,
            successColor: context.appColors.success,
            textStyle: context.font.bodyMedium,
          ),
          if (payoutTime != null)
            Row(
              mainAxisAlignment: .center,
              children: [
                Text(
                  context.loc.buyPayoutWillBeSentIn,
                  style: context.font.bodyMedium,
                  textAlign: .center,
                ),
                const Gap(4),
                Countdown(
                  until: payoutTime,
                  onTimeout: () {
                    // TODO: Maybe fetch the order again or notify the user
                  },
                ),
              ],
            ),
        ],
      ),
      actions: [
        // Only Bitcoin on-chain orders without a scheduled payout can be
        // accelerated.
        if (buyOrder.bitcoinAddress != null && buyOrder.transactionId == null)
          AccelerateTransactionListTile(
            orderId: buyOrder.orderId,
            onTap: () {
              context.pushNamed(
                BuyRoute.buyAccelerate.name,
                pathParameters: {'orderId': buyOrder.orderId},
              );
            },
          ),
        const Gap(16),
        BBButton.big(
          label: context.loc.buyViewDetails,
          onPressed: () {
            final txId = buyOrder.payjoin?.txid;
            if (txId != null) {
              context.pushNamed(
                TransactionsRoute.payjoinTransactionDetailsByTxId.name,
                pathParameters: {'txId': txId},
              );
            } else {
              context.pushNamed(
                TransactionsRoute.orderTransactionDetails.name,
                pathParameters: {'orderId': buyOrder.orderId},
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
