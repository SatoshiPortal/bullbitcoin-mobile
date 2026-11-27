import 'dart:async';

import 'package:bull_exchange/src/buy/domain/buy_payjoin_window.dart';
import 'package:bull_exchange/src/buy/domain/buy_state.dart';
import 'package:bull_exchange/src/buy/ui/buy_flow_shell.dart';
import 'package:bull_exchange/src/buy/ui/buy_payment_progress.dart';
import 'package:bull_exchange/src/buy/ui/widgets/accelerate_transaction_list_tile.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAsyncStatus,
        BullAsyncStatusState,
        BullButton,
        BullCountdown,
        BullPaymentNetwork,
        BullPaymentStepRail,
        BullSuccessScreen,
        BullTypographyX,
        Gap,
        PaymentAnimationPalette;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, FormatAmount;

/// The confirmed buy, followed by the flow's payout watch: what was bought,
/// the payjoin outcome while it applies, the scheduled payout countdown, and
/// Accelerate while a bitcoin payout is still batched.
class BuyDonePage extends StatefulWidget {
  const BuyDonePage({
    super.key,
    required this.done,
    required this.unit,
    required this.now,
    required this.onClose,
    required this.openOrder,
    required this.onAccelerate,
    required this.showPaymentAnimations,
  });

  final BuyDone done;
  final BitcoinUnit unit;
  final DateTime Function() now;
  final VoidCallback onClose;
  final void Function(String orderId) openOrder;
  final void Function(String orderId) onAccelerate;

  /// Resolves the payment-animation preference before the page picks between
  /// its rail and the hand-off to the transaction details.
  final Future<bool> Function() showPaymentAnimations;

  @override
  State<BuyDonePage> createState() => _BuyDonePageState();
}

class _BuyDonePageState extends State<BuyDonePage> {
  /// Null until the preference is read: the rail is not shown before then.
  bool? _animations;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  // Runs once per page: payout-watch updates rebuild it without re-running
  // this, so the hand-off navigates exactly once.
  Future<void> _resolve() async {
    final animations = await widget.showPaymentAnimations();
    if (!mounted) return;
    setState(() => _animations = animations);
    if (!animations) widget.openOrder(widget.done.order.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.done;
    final unit = widget.unit;
    final now = widget.now;
    final onClose = widget.onClose;
    final openOrder = widget.openOrder;
    final onAccelerate = widget.onAccelerate;
    final order = done.order;
    final payoutTime = order.scheduledPayoutTime;
    final failed = switch (done.watch) {
      WatchFailed() => true,
      WatchWatching() ||
      WatchPaused() ||
      WatchDone() ||
      WatchReceipt() ||
      WatchUnreadable() ||
      WatchTimedOut() ||
      WatchSessionEnded() ||
      WatchLeft() => false,
    };
    // The payout is still followed from the transaction details.
    final stale = switch (done.watch) {
      WatchUnreadable() || WatchTimedOut() => true,
      WatchWatching() ||
      WatchPaused() ||
      WatchDone() ||
      WatchReceipt() ||
      WatchFailed() ||
      WatchSessionEnded() ||
      WatchLeft() => false,
    };
    final payoutPending =
        order.payoutStatus != OrderPayoutStatus.completed && !failed;
    final network = buyPaymentNetwork(order);
    final palette =
        Theme.of(context).extension<PaymentAnimationPalette>() ??
        PaymentAnimationPalette.standard;
    final steps = [
      context.loc.buyStepOrderPlaced,
      context.loc.buyStepPayoutInProgress,
      if (network != BullPaymentNetwork.lightning) ...[
        context.loc.buyStepPayoutBroadcast,
        context.loc.buyStepPayoutSent,
      ] else
        context.loc.buyStepPaid,
    ];
    return BullSuccessScreen(
      title: context.loc.buyConfirmTitle,
      headline: context.loc.buyYouBought(
        formatBuyBitcoin(order, unit),
        FormatAmount.fiat(order.payinAmount, order.payinCurrency),
      ),
      onClose: onClose,
      message: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The rail carries its own dark palette: give it that background so
          // its white, orange and green segments read in a light theme too.
          if (_animations ?? false) ...[
            ColoredBox(
              color: palette.background,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BullPaymentStepRail(
                  progress: buyPaymentProgress(
                    steps: steps,
                    order: order,
                    watch: done.watch,
                  ),
                  network: network,
                  phase: buyPaymentPhase(order: order, watch: done.watch),
                  palette: palette,
                  reduced: MediaQuery.disableAnimationsOf(context),
                ),
              ),
            ),
            const Gap(16),
          ],
          BullAsyncStatus(
            state: switch (order.payjoinOutcome) {
              OrderPayjoinOutcome.none => BullAsyncStatusState.hidden,
              // Past its window the payout goes out as an ordinary
              // transaction, which the exchange reports only once sent.
              OrderPayjoinOutcome.inProgress
                  when !order.isAwaitingPayjoinAt(now()) =>
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
          if (payoutTime != null && payoutPending)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.loc.buyPayoutWillBeSentIn,
                  style: context.bullType.body,
                  textAlign: TextAlign.center,
                ),
                const Gap(4),
                BullCountdown(until: payoutTime),
              ],
            ),
          if (failed)
            Text(
              context.loc.buyPayoutFailed,
              style: context.bullType.body.copyWith(
                color: context.appColors.error,
              ),
              textAlign: TextAlign.center,
            ),
          if (stale)
            Text(
              context.loc.buyPayoutStillPending,
              style: context.bullType.body.copyWith(
                color: context.appColors.outline,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
      actions: [
        // Only a bitcoin on-chain payout not sent yet can be accelerated.
        if (order.bitcoinAddress != null &&
            order.transactionId == null &&
            payoutPending)
          AccelerateTransactionListTile(
            orderId: order.orderId,
            onTap: () => onAccelerate(order.orderId),
          ),
        const Gap(16),
        BullButton.secondary(
          label: context.loc.buyViewDetails,
          onPressed: () => openOrder(order.orderId),
        ),
      ],
    );
  }
}
