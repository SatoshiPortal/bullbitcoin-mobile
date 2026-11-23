import 'package:primitives/primitives.dart'
    show BitcoinUnit, ConvertAmount, FormatAmount;

import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin_window.dart';
import 'package:bull_exchange/src/buy/presentation/buy_bloc.dart';
import 'package:bull_exchange/src/buy/ui/buy_router.dart';
import 'package:bull_exchange/src/buy/ui/widgets/accelerate_transaction_list_tile.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart';

class BuySuccessScreen extends StatefulWidget {
  final void Function(BuildContext) onClose;
  final void Function(BuildContext, String) openOrder;

  const BuySuccessScreen({
    super.key,
    required this.onClose,
    required this.openOrder,
  });

  @override
  State<BuySuccessScreen> createState() => _BuySuccessScreenState();
}

class _BuySuccessScreenState extends State<BuySuccessScreen> {
  Timer? _orderRefreshTimer;

  @override
  void initState() {
    super.initState();
    _orderRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      final router = GoRouter.maybeOf(context);
      final configuration = router?.routerDelegate.currentConfiguration;
      final top = configuration?.lastOrNull;
      final route = top is ImperativeRouteMatch
          ? top.matches.last.route
          : top?.route;
      if (route is GoRoute && route.name != BuyRoute.buySuccess.name) return;
      final bloc = context.read<BuyBloc>();
      final state = bloc.state;
      final order = state.buyOrder;
      if (order == null || order.payoutStatus.isTerminal) {
        _orderRefreshTimer?.cancel();
        // Past the window the payjoin status no longer applies: drop it.
        setState(() {});
        return;
      }
      // Keep payout tracking active for plain sends and payjoin fallbacks too.
      if (!order.isAwaitingPayjoinAt(clock.now())) setState(() {});
      if (!state.isRefreshingOrder) bloc.add(const BuyEvent.refreshOrder());
    });
  }

  @override
  void dispose() {
    _orderRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyOrder = context.select((BuyBloc bloc) => bloc.state.buyOrder);
    if (buyOrder == null) return const SizedBox.shrink();
    final payoutAmountBtc = buyOrder.payoutAmount;
    final bitcoinUnit = context.select(
      (BuyBloc bloc) => bloc.state.displayBitcoinUnit,
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
      onClose: () => widget.onClose(context),
      message: Column(
        mainAxisSize: .min,
        children: [
          // The payout may still be negotiating a payjoin. Keep the outcome
          // visible without requiring the customer to open transaction details.
          BullAsyncStatus(
            state: switch (buyOrder.payjoinOutcome) {
              OrderPayjoinOutcome.none => BullAsyncStatusState.hidden,
              // Past its window the payout goes out as an ordinary transaction,
              // which the exchange reports only once it is sent.
              OrderPayjoinOutcome.inProgress
                  when !buyOrder.isAwaitingPayjoinAt(clock.now()) =>
                BullAsyncStatusState.hidden,
              OrderPayjoinOutcome.inProgress => BullAsyncStatusState.inProgress,
              OrderPayjoinOutcome.succeeded => BullAsyncStatusState.succeeded,
              OrderPayjoinOutcome.plainSend => BullAsyncStatusState.fallback,
              OrderPayjoinOutcome.abandoned => BullAsyncStatusState.hidden,
            },
            inProgressLabel: context.loc.payjoinInProgress,
            succeededLabel: context.loc.payjoinSucceeded,
            fallbackLabel: context.loc.payjoinBuyRegularSend,
            inProgressColor: context.appColors.secondary,
            successColor: context.appColors.success,
            textStyle: context.bullType.body,
          ),
          if (payoutTime != null)
            Row(
              mainAxisAlignment: .center,
              children: [
                Text(
                  context.loc.buyPayoutWillBeSentIn,
                  style: context.bullType.body,
                  textAlign: .center,
                ),
                const Gap(4),
                BullCountdown(until: payoutTime),
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
        BullButton.secondary(
          label: context.loc.buyViewDetails,
          onPressed: () {
            widget.openOrder(context, buyOrder.orderId);
          },
        ),
      ],
    );
  }
}
