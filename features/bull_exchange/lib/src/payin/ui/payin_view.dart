import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/payin/payin_l10n.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullScrollableColumn, BullTypographyX, Gap;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';

/// The page of a payin that is still running (sell and pay, composition §6
/// "Payin screen"). Terminal payin states are the flow's own pages. No page
/// offers a new send once a payin may be out: Verifying and Unverified only
/// look it up, Unseen resends the same signed transaction.
class PayinView extends StatelessWidget {
  const PayinView({
    super.key,
    required this.title,
    required this.state,
    required this.ui,
    required this.onEvent,
  });

  final String title;
  final PayinState<PayinSpend> state;
  final ExchangePayinUi ui;
  final void Function(PayinEvent<PayinSpend> event) onEvent;

  @override
  Widget build(BuildContext context) {
    FlowAction retry() =>
        FlowAction(context.loc.retry, () => onEvent(const PayinRetryPressed()));
    FlowAction back() => FlowAction(
      context.loc.cancel,
      () => onEvent(const PayinBackPressed()),
      primary: false,
    );
    FlowStatusPage page({
      String? headline,
      String? message,
      bool busy = false,
      bool isError = false,
      List<FlowAction> actions = const [],
    }) => FlowStatusPage(
      title: title,
      headline: headline,
      message: message,
      busy: busy,
      isError: isError,
      actions: actions,
    );
    return switch (state) {
      PayinBuilding() || PayinBroadcasting() => page(
        headline: context.loc.exchangePayinSending,
        busy: true,
      ),
      PayinWriteRefused(:final refusal) => page(
        message: refusal.toTranslated(context),
        isError: true,
        actions: [retry(), back()],
      ),
      PayinSendFailed(:final problem) => page(
        headline: context.loc.exchangePayinNotSent,
        message: problem.toTranslated(context),
        isError: true,
        actions: [retry(), back()],
      ),
      PayinRechecking() => page(
        message: context.loc.exchangeStepVerifying,
        busy: true,
      ),
      PayinRecheckFailed(:final problem) => page(
        message: problem.toTranslated(context),
        isError: true,
        actions: [retry(), back()],
      ),
      PayinPayjoinNegotiating() => page(
        headline: context.loc.exchangePayinPayjoinNegotiating,
        busy: true,
      ),
      PayinPayjoinPaused() => page(
        headline: context.loc.exchangePayinPayjoinPaused,
        actions: [retry()],
      ),
      PayinVerifying() => page(
        headline: context.loc.exchangePaymentOutcomeUnknownChecking,
        busy: true,
      ),
      PayinUnseen(:final txid) => page(
        headline: context.loc.exchangePayinUnseen,
        message: txid,
        actions: [
          FlowAction(
            context.loc.exchangePayinResend,
            () => onEvent(const PayinResendPressed()),
          ),
          FlowAction(
            context.loc.exchangeStepCheckAgain,
            () => onEvent(const PayinRetryPressed()),
            primary: false,
          ),
        ],
      ),
      PayinUnverified(:final txid, :final problem) => page(
        headline: context.loc.exchangeStepUnverified,
        message: [problem.toTranslated(context), ?txid].join('\n'),
        isError: true,
        actions: [
          FlowAction(
            context.loc.exchangeStepCheckAgain,
            () => onEvent(const PayinRetryPressed()),
          ),
        ],
      ),
      PayinWatching(:final txid, :final watch) => switch (watch) {
        WatchUnreadable() || WatchTimedOut() => page(
          headline: context.loc.exchangePaymentSentRefreshingOrder,
          message: [context.loc.exchangeStepTimedOut, ?txid].join('\n'),
          actions: [
            FlowAction(
              context.loc.exchangeStepCheckAgain,
              () => onEvent(const PayinWatchEvent(WatchRetryPressed())),
            ),
            FlowAction(
              context.loc.exchangePaymentSentLeave,
              () => onEvent(const PayinWatchEvent(WatchLeavePressed())),
              primary: false,
            ),
          ],
        ),
        WatchWatching() ||
        WatchPaused() ||
        WatchDone() ||
        WatchReceipt() ||
        WatchFailed() ||
        WatchSessionEnded() ||
        WatchLeft() => page(
          headline: context.loc.exchangePaymentSentRefreshingOrder,
          message: txid,
          busy: true,
        ),
      },
      PayinExternal(:final order, :final target) => _ExternalPayin(
        title: title,
        order: order,
        target: target,
        ui: ui,
        onBack: () => onEvent(const PayinBackPressed()),
      ),
      PayinExternalLeaving() => page(
        headline: context.loc.exchangePayinLeaveTitle,
        message: context.loc.exchangePayinLeaveMessage,
        actions: [
          FlowAction(
            context.loc.exchangePayinStay,
            () => onEvent(const PayinLeaveCancelled()),
          ),
          FlowAction(
            context.loc.exchangePaymentSentLeave,
            () => onEvent(const PayinLeaveConfirmed()),
            primary: false,
          ),
        ],
      ),
      PayinCompleted() ||
      PayinRefusedByExchange() ||
      PayinQuoteLapsed() ||
      PayinOrderEnded() ||
      PayinDepositRefused() ||
      PayinLeft() ||
      PayinLeftPending() ||
      PayinSessionEnded() => page(busy: true),
    };
  }
}

/// Pay the order from another wallet: the deposit of the order's rail and
/// the amount. The order watch runs meanwhile; Back asks first (PAY-4).
class _ExternalPayin extends StatelessWidget {
  const _ExternalPayin({
    required this.title,
    required this.order,
    required this.target,
    required this.ui,
    required this.onBack,
  });

  final String title;
  final Order order;
  final DepositTarget target;
  final ExchangePayinUi ui;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final deposit = switch (target) {
      OnchainDeposit(:final address) ||
      LiquidDeposit(:final address) => address,
      LightningInvoiceDeposit(:final invoice) => invoice,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(onPressed: onBack),
      ),
      body: SafeArea(
        child: BullScrollableColumn(
          padding: const EdgeInsets.all(24),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.loc.exchangePayinExternalTitle,
              style: context.bullType.subtitle,
            ),
            const Gap(16),
            Text(
              '${order.payinAmount} ${order.payinCurrency}',
              style: context.bullType.headline,
            ),
            const Gap(16),
            ui.addressViewer(context, deposit),
            const Gap(16),
            Text(
              context.loc.exchangePayinExternalWaiting,
              style: context.bullType.body,
            ),
            const Spacer(),
            BullButton.secondary(
              label: context.loc.exchangePaymentSentLeave,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}
