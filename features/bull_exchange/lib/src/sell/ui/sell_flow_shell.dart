import 'dart:async';

import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:bull_exchange/src/payin/ui/review_details.dart';
import 'package:bull_exchange/src/payin/ui/spend_options_section.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/payin/ui/payin_source_page.dart';
import 'package:bull_exchange/src/payin/ui/payin_view.dart';
import 'package:bull_exchange/src/payin/ui/quote_review_page.dart';
import 'package:bull_exchange/src/payout/ui/payout_requirement_view.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_failure_l10n.dart';
import 'package:bull_exchange/src/recipients/public/recipient_pick_screen.dart';
import 'package:bull_exchange/src/sell/presentation/sell_flow.dart';
import 'package:bull_exchange/src/sell/presentation/sell_flow_bloc.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_amount_page.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_payout_page.dart';
import 'package:bull_exchange/src/session/exchange_session_scope.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullDetailsTableItem, BullSuccessScreen;
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show FormatAmount;

/// The sell flow's one screen: its page stack is a function of the flow
/// state and Back is an event the machine answers.
class SellFlowShell extends StatefulWidget {
  const SellFlowShell({super.key, required this.ui});

  final ExchangePayinUi ui;

  @override
  State<SellFlowShell> createState() => _SellFlowShellState();
}

class _SellFlowShellState extends State<SellFlowShell> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onShow: () => _visible(true),
    onHide: () => _visible(false),
  );

  void _visible(bool visible) {
    final bloc = context.read<SellFlowBloc>();
    if (!bloc.isClosed) bloc.add(SellVisibilityChanged(visible: visible));
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
    return BlocConsumer<SellFlowBloc, SellFlowState>(
      listenWhen: (previous, current) =>
          (current is SellClosed && previous is! SellClosed) ||
          (current is SellDone && previous is! SellDone),
      listener: (context, state) {
        switch (state) {
          case SellDone():
            unawaited(ExchangeSessionScope.refresh(context));
          case SellClosed():
            if (context.canPop()) {
              context.pop();
            } else {
              BullExchangeNavigation.goToDashboard(context);
            }
          case SellLoading() ||
              SellAmount() ||
              SellSource() ||
              SellPayoutPick() ||
              SellRecipient() ||
              SellRequirements() ||
              SellOrdering() ||
              SellPaying() ||
              SellSessionEnded():
            break;
        }
      },
      builder: (context, state) {
        final bloc = context.read<SellFlowBloc>();
        final pages = sellPagesFor(
          state,
          ui: widget.ui,
          onEvent: bloc.add,
          now: clock.now,
          states: bloc.stream,
          current: () => bloc.state,
        );
        return PopScope(
          canPop: state is SellClosed,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const SellBackPressed());
          },
          child: Navigator(
            pages: pages,
            onDidRemovePage: (page) {
              if (identical(bloc.state, state) && page.key == pages.last.key) {
                bloc.add(const SellBackPressed());
              }
            },
          ),
        );
      },
    );
  }
}

const _amountKey = ValueKey('sell-amount');
const _sourceKey = ValueKey('sell-source');
const _payoutKey = ValueKey('sell-payout');
const _recipientKey = ValueKey('sell-recipient');
const _requirementKey = ValueKey('sell-requirement');
const _orderKey = ValueKey('sell-order');
const _payinKey = ValueKey('sell-payin');
const _endKey = ValueKey('sell-end');

/// The page stack of [state].
List<Page<void>> sellPagesFor(
  SellFlowState state, {
  required ExchangePayinUi ui,
  required void Function(SellFlowEvent event) onEvent,
  required DateTime Function() now,
  Stream<SellFlowState> states = const Stream.empty(),
  SellFlowState Function()? current,
}) {
  SpendOptionsState spendOf(SellFlowState state) => switch (state) {
    SellOrdering(:final spend) => spend,
    SellLoading() ||
    SellAmount() ||
    SellSource() ||
    SellPayoutPick() ||
    SellRecipient() ||
    SellRequirements() ||
    SellPaying() ||
    SellDone() ||
    SellSessionEnded() ||
    SellClosed() => const SpendOptionsNone(),
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
        title: context.loc.sellTitle,
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
    () => onEvent(const SellBackPressed()),
    primary: false,
  );
  FlowAction retry(BuildContext context) =>
      FlowAction(context.loc.retry, () => onEvent(const SellRetryPressed()));
  FlowAction leave(BuildContext context) => FlowAction(
    context.loc.exchangePaymentSentLeave,
    () => onEvent(const SellDonePressed()),
  );

  List<Page<void>> amountPages(SellOpen open, AmountEntryState amount) =>
      switch (amount) {
        final AmountEditing editing => [
          page(
            _amountKey,
            SellAmountPage(open: open, editing: editing, onEvent: onEvent),
          ),
        ],
        AmountKycDetour() => [
          status(
            _amountKey,
            headline: (context) => context.loc.sellKycPendingTitle,
            message: (context) => context.loc.sellKycPendingDescription,
            actions: (context) => [
              FlowAction(context.loc.sellCompleteKYC, () {
                unawaited(
                  context
                      .push<void>(BullExchangeNavigation.kycPath)
                      .then((_) => onEvent(const SellKycReturned())),
                );
              }),
              back(context),
            ],
          ),
        ],
        AmountNoMarket() ||
        AmountFundingDetour() ||
        AmountDone() ||
        AmountSessionRejected() => [status(_amountKey, busy: true)],
      };
  List<Page<void>> enteredPages(SellOpen open, EnteredAmount amount) =>
      amountPages(
        open,
        AmountEditing(
          draft: amount.draft,
          quote: RateReady(amount.rate),
          context: open.context.amountContext,
        ),
      );
  List<Page<void>> sourcePages(SellOpen open, EnteredAmount amount) => [
    ...enteredPages(open, amount),
    page(
      _sourceKey,
      Builder(
        builder: (context) => PayinSourcePage(
          title: context.loc.sellTitle,
          ui: ui,
          onPicked: (source) => onEvent(SellSourcePicked(source)),
          onBack: () => onEvent(const SellBackPressed()),
        ),
      ),
    ),
  ];
  List<Page<void>> payoutPages(SellOpen open, EnteredAmount amount) => [
    ...sourcePages(open, amount),
    page(_payoutKey, SellPayoutPage(onEvent: onEvent)),
  ];
  List<Page<void>> recipientPages(
    SellOpen open,
    EnteredAmount amount, {
    Recipient? refused,
  }) => [
    ...payoutPages(open, amount),
    page(
      _recipientKey,
      Builder(
        builder: (context) => RecipientPickScreen(
          filter: sellRecipientFilter(amount.market),
          onPicked: (recipient) => onEvent(SellRecipientPicked(recipient)),
          problem: refused == null
              ? null
              : const RecipientsSelectionFailure().toTranslated(context),
        ),
      ),
    ),
  ];
  List<Page<void>> orderBase(SellOpen open, SellRequest request) =>
      switch (request.payout) {
        SellToBalance() => payoutPages(open, request.amount),
        SellToRecipient() => recipientPages(open, request.amount),
      };

  return switch (state) {
    SellLoading(load: ContextFailed(:final problem)) => [
      status(
        _amountKey,
        message: (context) => problem.toTranslated(context),
        isError: true,
        actions: (context) => [retry(context), back(context)],
      ),
    ],
    SellLoading() => [status(_amountKey, busy: true)],
    SellAmount(:final open, :final amount) => amountPages(open, amount),
    SellSource(:final open, :final amount) => sourcePages(open, amount),
    SellPayoutPick(:final open, :final amount) => payoutPages(open, amount),
    SellRecipient(:final open, :final amount, :final refused) => recipientPages(
      open,
      amount,
      refused: refused,
    ),
    SellRequirements(:final open, :final amount, :final requirements) => [
      ...recipientPages(open, amount),
      page(
        _requirementKey,
        Builder(
          builder: (context) => PayoutRequirementView(
            title: context.loc.sellTitle,
            running: requirements,
            onEvent: (event) => onEvent(SellRequirementsChanged(event)),
          ),
        ),
      ),
    ],
    SellOrdering(:final open, :final request, :final order, :final spend) => [
      ...orderBase(open, request),
      switch (order) {
        OrderQuoted(:final quoted, :final status) => page(
          _orderKey,
          Builder(
            builder: (context) => QuoteReviewPage(
              title: context.loc.sellTitle,
              rows: sellReviewRows(context, quoted.order),
              deadline: quoted.order.confirmationDeadline,
              refreshLabel: context.loc.sellPriceWillRefreshIn,
              details: [
                ?payinDepositRow(
                  context,
                  label: context.loc.sellDepositAddress,
                  order: quoted.order,
                  source: request.source,
                  ui: ui,
                ),
                ...switch (request.payout) {
                  SellToBalance() => [
                    BullDetailsTableItem(
                      label: context.loc.sellPayoutRecipient,
                      displayValue: _balanceName(
                        context,
                        request.amount.market.currency,
                      ),
                    ),
                  ],
                  SellToRecipient(:final recipient) => recipientReviewRows(
                    context,
                    recipient: recipient,
                    methodLabel: context.loc.recipientsPayoutMethod,
                    nameLabel: context.loc.sellPayoutRecipient,
                  ),
                },
                SpendOptionsSection(
                  spend: spend,
                  changes: states.map(spendOf),
                  current: () => spendOf(current?.call() ?? state),
                  labels: (
                    feePriority: context.loc.sellFeePriority,
                    fastest: context.loc.sellFastest,
                    networkFees: context.loc.sellSendPaymentNetworkFees,
                    advancedSettings: context.loc.sellAdvancedSettings,
                    advancedOptions: context.loc.sellAdvancedOptions,
                    replaceByFee: context.loc.sellReplaceByFeeActivated,
                    selectCoins: context.loc.sellSelectCoinsManually,
                    done: context.loc.sellDone,
                    feesUnavailable: context.loc.sellErrorFeesUnavailable,
                  ),
                  payjoinOffered: payjoinOffered(quoted.order, request.source),
                  amountSat: payinAmountSat(quoted.order),
                  exchangeRate: payinExchangeRate(quoted.order),
                  fiatCurrency: quoted.order.payoutCurrency,
                  onEvent: (event) => onEvent(SellSpendChanged(event)),
                ),
              ],
              status: status,
              canConfirm: spendOptionsChosen(spend) is SpendChosen,
              onConfirm: () => onEvent(SellConfirmPressed(now())),
              onRetry: () => onEvent(const SellRetryPressed()),
              onBack: () => onEvent(const SellBackPressed()),
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
              () => onEvent(const SellRetryPressed()),
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
        OrderLeft() => status(_orderKey, busy: true),
      },
    ],
    SellPaying(:final payin) => [
      switch (payin) {
        PayinRefusedByExchange(:final order, :final txid) => status(
          _payinKey,
          headline: (context) => context.loc.exchangePayinRefusedByExchange,
          message: (context) => [
            context.loc.sellOrderNumber,
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
              title: context.loc.sellTitle,
              state: payin,
              ui: ui,
              onEvent: (event) => onEvent(SellPayinChanged(event)),
              externalLabels: (
                refreshIn: context.loc.sellPriceWillRefreshIn,
                copyInvoice: context.loc.sellCopyInvoice,
                showQr: context.loc.sellShowQrCode,
                qrTitle: context.loc.sellQrCode,
              ),
            ),
          ),
        ),
      },
    ],
    SellDone(:final order, :final txid) => [
      page(
        _endKey,
        Builder(
          builder: (context) => BullSuccessScreen(
            title: context.loc.sellTitle,
            headline: context.loc.exchangePayinReceived,
            onClose: () => onEvent(const SellDonePressed()),
            actions: [
              BullButton.secondary(
                label: context.loc.sellViewDetailsButton,
                onPressed: () => txid != null && order.payjoinBip21 != null
                    ? ui.openPayjoinTransaction(context, txid)
                    : ui.openOrder(
                        context,
                        order.orderId,
                        returnToExchange: true,
                      ),
              ),
            ],
          ),
        ),
      ),
    ],
    SellSessionEnded() => [
      status(
        _endKey,
        message: (context) => context.loc.exchangeFlowSessionEnded,
        actions: (context) => [
          FlowAction(
            context.loc.closeDialogButton,
            () => onEvent(const SellDonePressed()),
          ),
        ],
      ),
    ],
    SellClosed() => [status(_endKey)],
  };
}

/// The rows of a quoted sell or payment order.
List<(String, String)> sellReviewRows(BuildContext context, Order order) => [
  (context.loc.sellOrderNumber, '${order.orderNumber}'),
  (context.loc.sellPayinAmount, '${order.payinAmount} ${order.payinCurrency}'),
  (
    context.loc.sellPayoutAmount,
    FormatAmount.fiat(order.payoutAmount, order.payoutCurrency),
  ),
  if (_rateOf(order) case (final rate, final currency))
    (context.loc.sellExchangeRate, FormatAmount.fiat(rate, currency)),
];

(double, String)? _rateOf(Order order) {
  final (amount, currency) = order is SellOrder
      ? (order.exchangeRateAmount, order.exchangeRateCurrency)
      : order is FiatPaymentOrder
      ? (order.exchangeRateAmount, order.exchangeRateCurrency)
      : (null, null);
  return amount == null ? null : (amount, currency ?? order.payoutCurrency);
}

String _balanceName(BuildContext context, FiatCurrency currency) =>
    switch (currency) {
      FiatCurrency.cad => context.loc.sellCadBalance,
      FiatCurrency.crc => context.loc.sellCrcBalance,
      FiatCurrency.eur => context.loc.sellEurBalance,
      FiatCurrency.usd => context.loc.sellUsdBalance,
      FiatCurrency.mxn => context.loc.sellMxnBalance,
      FiatCurrency.ars => context.loc.sellArsBalance,
      FiatCurrency.cop => context.loc.sellCopBalance,
    };
