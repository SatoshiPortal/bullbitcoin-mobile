import 'dart:async';

import 'package:transactions/routes.dart';
import 'package:bull_exchange/src/payin/spend_options_state.dart';
import 'package:bull_exchange/src/payin/ui/review_details.dart';
import 'package:bull_exchange/src/payin/ui/spend_options_section.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:bull_exchange/src/pay/domain/pay_state.dart';
import 'package:bull_exchange/src/pay/domain/pay_event.dart';
import 'package:bull_exchange/src/pay/presentation/pay_flow_bloc.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_amount_page.dart';
import 'package:bull_exchange/src/pay/ui/widgets/sinpe_receipt_card.dart';
import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/payin/ui/payin_source_page.dart';
import 'package:bull_exchange/src/payin/ui/payin_view.dart';
import 'package:bull_exchange/src/payin/ui/quote_review_page.dart';
import 'package:bull_exchange/src/payout/ui/payout_requirement_view.dart';
import 'package:bull_exchange/src/presentation/exchange_failure_l10n.dart';
import 'package:bull_exchange/src/recipients/public/recipient_pick_screen.dart';
import 'package:bull_exchange/src/sell/ui/sell_flow_shell.dart'
    show sellReviewRows;
import 'package:bull_exchange/src/session/exchange_session_scope.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullScrollableColumn, BullSuccessScreen, Gap;
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The pay flow's one screen: its page stack is a function of the flow
/// state and Back is an event the machine answers.
class PayFlowShell extends StatefulWidget {
  const PayFlowShell({super.key, required this.ui});

  final ExchangePayinUi ui;

  @override
  State<PayFlowShell> createState() => _PayFlowShellState();
}

class _PayFlowShellState extends State<PayFlowShell> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onShow: () => _visible(true),
    onHide: () => _visible(false),
  );

  void _visible(bool visible) {
    final bloc = context.read<PayFlowBloc>();
    if (!bloc.isClosed) bloc.add(PayVisibilityChanged(visible: visible));
  }

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PayFlowBloc, PayFlowState>(
      listenWhen: (previous, current) =>
          (current is PayClosed && previous is! PayClosed) ||
          (current is PayDone && previous is! PayDone),
      listener: (context, state) {
        switch (state) {
          case PayDone():
            unawaited(ExchangeSessionScope.refresh(context));
          case PayClosed():
            if (context.canPop()) {
              context.pop();
            } else {
              BullExchangeNavigation.goToDashboard(context);
            }
          case PayLoading() ||
              PayRecipient() ||
              PayRequirements() ||
              PayAmount() ||
              PaySource() ||
              PayOrdering() ||
              PayPaying() ||
              PaySessionEnded():
            break;
        }
      },
      builder: (context, state) {
        final bloc = context.read<PayFlowBloc>();
        final pages = payPagesFor(
          state,
          ui: widget.ui,
          onEvent: bloc.add,
          now: clock.now,
          states: bloc.stream,
          current: () => bloc.state,
        );
        return PopScope(
          canPop: state is PayClosed,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const PayBackPressed());
          },
          child: Navigator(
            pages: pages,
            onDidRemovePage: (page) {
              if (identical(bloc.state, state) && page.key == pages.last.key) {
                bloc.add(const PayBackPressed());
              }
            },
          ),
        );
      },
    );
  }
}

const _recipientKey = ValueKey('pay-recipient');
const _requirementKey = ValueKey('pay-requirement');
const _amountKey = ValueKey('pay-amount');
const _sourceKey = ValueKey('pay-source');
const _orderKey = ValueKey('pay-order');
const _payinKey = ValueKey('pay-payin');
const _endKey = ValueKey('pay-end');

/// The page stack of [state].
List<Page<void>> payPagesFor(
  PayFlowState state, {
  required ExchangePayinUi ui,
  required void Function(PayFlowEvent event) onEvent,
  required DateTime Function() now,
  Stream<PayFlowState> states = const Stream.empty(),
  PayFlowState Function()? current,
}) {
  SpendOptionsState spendOf(PayFlowState state) => switch (state) {
    PayOrdering(:final spend) => spend,
    PayLoading() ||
    PayRecipient() ||
    PayRequirements() ||
    PayAmount() ||
    PaySource() ||
    PayPaying() ||
    PayDone() ||
    PaySessionEnded() ||
    PayClosed() => const SpendOptionsNone(),
  };
  Page<void> page(LocalKey key, Widget child) =>
      MaterialPage(key: key, child: child);
  Page<void> status(
    LocalKey key, {
    String Function(BuildContext)? headline,
    String Function(BuildContext)? message,
    bool busy = false,
    bool isError = false,
    List<FlowAction> Function(BuildContext)? actions,
  }) => page(
    key,
    Builder(
      builder: (context) => FlowStatusPage(
        title: context.loc.payTitle,
        onBack: () => onEvent(const PayBackPressed()),
        headline: headline?.call(context),
        message: message?.call(context),
        busy: busy,
        isError: isError,
        actions: actions?.call(context) ?? const [],
      ),
    ),
  );
  FlowAction back(BuildContext context) => FlowAction(
    context.loc.cancel,
    () => onEvent(const PayBackPressed()),
    primary: false,
  );
  FlowAction retry(BuildContext context) =>
      FlowAction(context.loc.retry, () => onEvent(const PayRetryPressed()));
  FlowAction leave(BuildContext context) => FlowAction(
    context.loc.exchangePaymentSentLeave,
    () => onEvent(const PayDonePressed()),
  );

  List<Page<void>> recipientPages({Recipient? refused}) => [
    page(
      _recipientKey,
      Builder(
        builder: (context) => RecipientPickScreen(
          filter: payRecipientFilter,
          onPicked: (recipient) => onEvent(PayRecipientPicked(recipient)),
          onBack: () => onEvent(const PayBackPressed()),
          problem: refused == null
              ? null
              : const ExchangeRecipientsSelectionFailure().toTranslated(
                  context,
                ),
        ),
      ),
    ),
  ];
  List<Page<void>> amountPages(AmountEntryState amount) => [
    ...recipientPages(),
    switch (amount) {
      final AmountEditing editing => page(
        _amountKey,
        PayAmountPage(editing: editing, onEvent: onEvent),
      ),
      AmountKycDetour() => status(
        _amountKey,
        headline: (context) => context.loc.sellKycPendingTitle,
        message: (context) => context.loc.sellKycPendingDescription,
        actions: (context) => [
          FlowAction(context.loc.sellCompleteKYC, () {
            unawaited(
              context
                  .push<void>(BullExchangeNavigation.kycPath)
                  .then((_) => onEvent(const PayKycReturned())),
            );
          }),
          back(context),
        ],
      ),
      AmountNoMarket() ||
      AmountFundingDetour() ||
      AmountDone() ||
      AmountSessionRejected() => status(_amountKey, busy: true),
    },
  ];
  List<Page<void>> enteredPages(PayOpen open, EnteredAmount amount) =>
      amountPages(
        AmountEditing(
          draft: amount.draft,
          quote: RateReady(amount.rate),
          context: open.context.amountContext,
        ),
      );
  List<Page<void>> sourcePages(PayOpen open, EnteredAmount amount) => [
    ...enteredPages(open, amount),
    page(
      _sourceKey,
      Builder(
        builder: (context) => PayinSourcePage(
          title: context.loc.payTitle,
          ui: ui,
          onPicked: (source) => onEvent(PaySourcePicked(source)),
          onBack: () => onEvent(const PayBackPressed()),
        ),
      ),
    ),
  ];

  return switch (state) {
    PayLoading(load: ContextFailed(:final problem)) => [
      status(
        _recipientKey,
        message: (context) => problem.toTranslated(context),
        isError: true,
        actions: (context) => [retry(context), back(context)],
      ),
    ],
    PayLoading() => [status(_recipientKey, busy: true)],
    PayRecipient(:final refused) => recipientPages(refused: refused),
    PayRequirements(:final requirements) => [
      ...recipientPages(),
      page(
        _requirementKey,
        Builder(
          builder: (context) => PayoutRequirementView(
            title: context.loc.payTitle,
            running: requirements,
            onEvent: (event) => onEvent(PayRequirementsChanged(event)),
            onBack: () => onEvent(const PayBackPressed()),
          ),
        ),
      ),
    ],
    PayAmount(:final amount) => amountPages(amount),
    PaySource(:final open, :final amount) => sourcePages(open, amount),
    PayOrdering(:final open, :final request, :final order, :final spend) => [
      ...sourcePages(open, request.amount),
      switch (order) {
        OrderQuoted(:final quoted, :final status) => page(
          _orderKey,
          Builder(
            builder: (context) => QuoteReviewPage(
              title: context.loc.payTitle,
              rows: [
                (
                  context.loc.payRecipientName,
                  request.recipient.chosen.recipient.onRail.displayName ?? '-',
                ),
                ...sellReviewRows(context, quoted.order),
              ],
              deadline: quoted.order.confirmationDeadline,
              refreshLabel: context.loc.payPriceRefreshIn,
              details: [
                ?payinDepositRow(
                  context,
                  label: context.loc.payDepositAddress,
                  order: quoted.order,
                  source: request.source,
                ),
                ...recipientReviewRows(
                  context,
                  recipient: request.recipient,
                  methodLabel: context.loc.payRecipientType,
                  nameLabel: context.loc.payRecipientName,
                ),
                ?payinWalletRow(
                  context,
                  label: context.loc.payPayFromWallet,
                  source: request.source,
                  secureBitcoinWallet: context.loc.paySecureBitcoinWallet,
                  instantPayments: context.loc.payInstantPayments,
                ),
                SpendOptionsSection(
                  spend: spend,
                  changes: states.map(spendOf),
                  current: () => spendOf(current?.call() ?? state),
                  labels: (
                    feePriority: context.loc.payFeePriority,
                    fastest: context.loc.payFastest,
                    networkFees: context.loc.payNetworkFees,
                    advancedSettings: context.loc.payAdvancedSettings,
                    advancedOptions: context.loc.payAdvancedOptions,
                    replaceByFee: context.loc.payRbfActivated,
                    selectCoins: context.loc.paySelectCoinsManually,
                    done: context.loc.payDone,
                    feesUnavailable: context.loc.payErrorFeesUnavailable,
                  ),
                  payjoinOffered: payjoinOffered(quoted.order, request.source),
                  amountSat: payinAmountSat(quoted.order),
                  exchangeRate: payinExchangeRate(quoted.order),
                  fiatCurrency: quoted.order.payoutCurrency,
                  onEvent: (event) => onEvent(PaySpendChanged(event)),
                ),
              ],
              status: status,
              canConfirm: spendOptionsChosen(spend) is SpendChosen,
              onConfirm: () => onEvent(PayConfirmPressed(now())),
              onRetry: () => onEvent(const PayRetryPressed()),
              onBack: () => onEvent(const PayBackPressed()),
            ),
          ),
        ),
        OrderWriteRefused(:final refusal) => status(
          _orderKey,
          message: (context) => refusal.toTranslated(context),
          isError: true,
          actions: (context) => [retry(context), back(context)],
        ),
        OrderCreateFailed(:final problem) => status(
          _orderKey,
          message: (context) => problem.toTranslated(context),
          isError: true,
          actions: (context) => [retry(context), back(context)],
        ),
        OrderUnverified(:final problem) => status(
          _orderKey,
          headline: (context) => context.loc.exchangeStepUnverified,
          message: (context) => problem.toTranslated(context),
          isError: true,
          actions: (context) => [
            FlowAction(
              context.loc.exchangeStepCheckAgain,
              () => onEvent(const PayRetryPressed()),
            ),
            back(context),
          ],
        ),
        OrderVerifying() => status(
          _orderKey,
          message: (context) => context.loc.exchangeStepVerifying,
          busy: true,
        ),
        OrderCreating() ||
        OrderPlaced() ||
        OrderCommitted() ||
        OrderSessionEnded() ||
        OrderAmountRefused() ||
        OrderLeft() => status(_orderKey, busy: true),
      },
    ],
    PayPaying(:final payin) => [
      switch (payin) {
        PayinRefusedByExchange(:final order, :final txid) => status(
          _payinKey,
          headline: (context) => context.loc.exchangePayinRefusedByExchange,
          message: (context) => [
            context.loc.payOrderNumber,
            '${order.orderNumber}',
            ?txid,
          ].join(' '),
          isError: true,
          actions: (context) => [leave(context)],
        ),
        PayinOrderEnded() => status(
          _payinKey,
          headline: (context) => context.loc.exchangePayinOrderEnded,
          isError: true,
          actions: (context) => [leave(context)],
        ),
        PayinDepositRefused() => status(
          _payinKey,
          headline: (context) => context.loc.exchangePayinDepositRefused,
          isError: true,
          actions: (context) => [leave(context)],
        ),
        PayinBuilding() ||
        PayinBroadcasting() ||
        PayinWriteRefused() ||
        PayinSendFailed() ||
        PayinRechecking() ||
        PayinRecheckFailed() ||
        PayinPayjoinNegotiating() ||
        PayinPayjoinPaused() ||
        PayinVerifying() ||
        PayinUnseen() ||
        PayinUnverified() ||
        PayinWatching() ||
        PayinExternal() ||
        PayinExternalLeaving() ||
        PayinCompleted() ||
        PayinQuoteLapsed() ||
        PayinLeft() ||
        PayinLeftPending() ||
        PayinSessionEnded() => page(
          _payinKey,
          Builder(
            builder: (context) => PayinView(
              title: context.loc.payTitle,
              state: payin,
              onEvent: (event) => onEvent(PayPayinChanged(event)),
              onBack: () => onEvent(const PayBackPressed()),
              externalLabels: (
                refreshIn: context.loc.payPriceRefreshIn,
                copyInvoice: context.loc.payCopyInvoice,
                showQr: context.loc.payShowQrCode,
                qrTitle: context.loc.payQrCode,
              ),
            ),
          ),
        ),
      },
    ],
    PayDone(receipt: null, :final order, :final txid) => [
      page(
        _endKey,
        Builder(
          builder: (context) => BullSuccessScreen(
            title: context.loc.payTitle,
            headline: context.loc.exchangePayinReceived,
            onClose: () => onEvent(const PayDonePressed()),
            message: payinDoneMessage(
              context,
              order,
              balanceNote: order is FiatPaymentOrder
                  ? (order.isPayinCompleted
                        ? context.loc.payPaymentPayinConfirmedDescriptionDetails
                        : context.loc.payPaymentInProgressDescriptionDetails)(
                      order.payoutAmountToDisplay,
                      order.recipientToDisplay ?? context.loc.payNotAvailable,
                    )
                  : null,
            ),
            actions: [
              BullButton.secondary(
                label: context.loc.payViewDetails,
                onPressed: () => TransactionsNavigation.openDetails(
                  context,
                  txid != null && order.payjoinBip21 != null
                      ? TransactionDetailsTarget.payjoinByTxId(txid)
                      : TransactionDetailsTarget.order(order.orderId),
                  returnToExchange: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
    final PayDone done => [
      page(
        _endKey,
        Builder(
          builder: (context) => _ReceiptPage(done: done, onEvent: onEvent),
        ),
      ),
    ],
    PaySessionEnded() => [
      status(
        _endKey,
        message: (context) => context.loc.exchangeFlowSessionEnded,
        actions: (context) => [
          FlowAction(
            context.loc.closeDialogButton,
            () => onEvent(const PayDonePressed()),
          ),
        ],
      ),
    ],
    PayClosed() => [status(_endKey)],
  };
}

/// A SINPE payment's receipt, updated by the bounded receipt watch; a watch
/// that timed out or could not read offers Check again.
class _ReceiptPage extends StatelessWidget {
  const _ReceiptPage({required this.done, required this.onEvent});

  final PayDone done;
  final void Function(PayFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) {
    final latest = done.latest;
    final stalled = switch (done.receipt) {
      WatchUnreadable() || WatchTimedOut() => true,
      null ||
      WatchWatching() ||
      WatchPaused() ||
      WatchDone() ||
      WatchReceipt() ||
      WatchFailed() ||
      WatchSessionEnded() ||
      WatchLeft() => false,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.payOrderDetails),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: context.loc.closeDialogButton,
            icon: const Icon(Icons.close),
            onPressed: () => onEvent(const PayDonePressed()),
          ),
        ],
      ),
      body: SafeArea(
        child: BullScrollableColumn(
          children: [
            if (latest is FiatPaymentOrder)
              SinpeReceiptCard(
                order: latest,
                // "Sent" only once the payout completed, as before C5a.
                showSuccessAnimation:
                    latest.payoutStatus == OrderPayoutStatus.completed,
              ),
            const Gap(24),
            const Spacer(),
            if (stalled) ...[
              BullButton.secondary(
                label: context.loc.exchangeStepCheckAgain,
                onPressed: () => onEvent(const PayRetryPressed()),
              ),
              const Gap(8),
            ],
            BullButton.primary(
              label: context.loc.payDone,
              onPressed: () => onEvent(const PayDonePressed()),
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}
