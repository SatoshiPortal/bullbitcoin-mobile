import 'dart:async';

import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/presentation/buy_flow_bloc.dart';
import 'package:bull_exchange/src/buy/ui/buy_router.dart';
import 'package:bull_exchange/src/buy/ui/screens/buy_done_page.dart';
import 'package:bull_exchange/src/buy/ui/screens/buy_entry_page.dart';
import 'package:bull_exchange/src/buy/ui/buy_payout_method_label.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:bull_exchange/src/exchange_payout_field.dart';
import 'package:bull_exchange/src/funding/fund_exchange_router.dart';
import 'package:bull_exchange/src/payin/ui/quote_review_page.dart';
import 'package:bull_exchange/src/session/exchange_session_scope.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart'
    show BitcoinUnit, ConvertAmount, FormatAmount;

/// What the buy pages need from the host.
typedef BuyFlowUi = ({
  ExchangePayoutField payoutField,
  String bitcoinAsset,
  void Function(BuildContext context, String orderId) openOrder,
  Future<bool> Function() showPaymentAnimations,
});

/// The buy flow's one screen: its page stack is a function of the flow
/// state and Back is an event the machine answers.
class BuyFlowShell extends StatefulWidget {
  const BuyFlowShell({super.key, required this.ui, required this.unit});

  final BuyFlowUi ui;

  /// The user's bitcoin unit, for the amount field and the amounts shown.
  final Stream<BitcoinUnit> unit;

  @override
  State<BuyFlowShell> createState() => _BuyFlowShellState();
}

class _BuyFlowShellState extends State<BuyFlowShell> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onShow: () => _visible(true),
    onHide: () => _visible(false),
  );
  late final StreamSubscription<BitcoinUnit> _units;
  BitcoinUnit _unit = BitcoinUnit.btc;

  void _visible(bool visible) {
    final bloc = context.read<BuyFlowBloc>();
    if (!bloc.isClosed) bloc.add(BuyVisibilityChanged(visible: visible));
  }

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _units = widget.unit.listen((unit) {
      if (mounted) setState(() => _unit = unit);
    });
  }

  @override
  void dispose() {
    unawaited(_units.cancel());
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BuyFlowBloc, BuyFlowState>(
      listenWhen: (previous, current) =>
          (current is BuyClosed && previous is! BuyClosed) ||
          (current is BuyDone && previous is! BuyDone),
      listener: (context, state) {
        switch (state) {
          case BuyDone():
            unawaited(ExchangeSessionScope.refresh(context));
          case BuyClosed():
            if (context.canPop()) {
              context.pop();
            } else {
              BullExchangeNavigation.goToDashboard(context);
            }
          case BuyLoading() ||
              BuyEntry() ||
              BuyOrdering() ||
              BuyReview() ||
              BuyConfirming() ||
              BuySessionEnded():
            break;
        }
      },
      builder: (context, state) {
        final bloc = context.read<BuyFlowBloc>();
        final pages = buyPagesFor(
          state,
          ui: widget.ui,
          unit: _unit,
          onEvent: bloc.add,
          now: clock.now,
        );
        return PopScope(
          canPop: state is BuyClosed,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const BuyBackPressed());
          },
          child: Navigator(
            pages: pages,
            onDidRemovePage: (page) {
              if (identical(bloc.state, state) && page.key == pages.last.key) {
                bloc.add(const BuyBackPressed());
              }
            },
          ),
        );
      },
    );
  }
}

const _entryKey = ValueKey('buy-entry');
const _detourKey = ValueKey('buy-detour');
const _orderKey = ValueKey('buy-order');
const _confirmKey = ValueKey('buy-confirm');
const _endKey = ValueKey('buy-end');

/// The page stack of [state].
List<Page<void>> buyPagesFor(
  BuyFlowState state, {
  required BuyFlowUi ui,
  required BitcoinUnit unit,
  required void Function(BuyFlowEvent event) onEvent,
  required DateTime Function() now,
}) {
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
        title: context.loc.buyInputTitle,
        onBack: () => onEvent(const BuyBackPressed()),
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
    () => onEvent(const BuyBackPressed()),
    primary: false,
  );
  FlowAction retry(BuildContext context) =>
      FlowAction(context.loc.retry, () => onEvent(const BuyRetryPressed()));

  Page<void> entryPage(BuyEntry entry) => page(
    _entryKey,
    BuyEntryPage(
      entry: entry,
      unit: unit,
      payoutField: ui.payoutField,
      onEvent: onEvent,
    ),
  );

  List<Page<void>> entryPages(BuyEntry entry) => [
    entryPage(entry),
    ...switch (entry.amount) {
      AmountKycDetour() => [
        status(
          _detourKey,
          headline: (context) => context.loc.buyInputKycPending,
          message: (context) => context.loc.buyInputKycMessage,
          actions: (context) => [
            FlowAction(context.loc.buyInputCompleteKyc, () {
              unawaited(
                context
                    .push<void>(BullExchangeNavigation.kycPath)
                    .then((_) => onEvent(const BuyKycReturned())),
              );
            }),
            back(context),
          ],
        ),
      ],
      AmountFundingDetour() => [
        status(
          _detourKey,
          headline: (context) => context.loc.buyInputInsufficientBalance,
          message: (context) => context.loc.buyInputInsufficientBalanceMessage,
          actions: (context) => [
            FlowAction(context.loc.buyInputFundAccount, () {
              unawaited(
                context
                    .push<void>(FundExchangeRoute.fundExchange.path)
                    .then((_) => onEvent(const BuyFundingReturned())),
              );
            }),
            back(context),
          ],
        ),
      ],
      AmountEditing() ||
      AmountNoMarket() ||
      AmountDone() ||
      AmountSessionRejected() => const <Page<void>>[],
    },
  ];

  /// The entry under an order: what Back returns to.
  Page<void> entryUnder(BuyOpen open, BuyRequest request) =>
      entryPage(buyEntryUnder(open, request));

  Page<void> review(
    BuyOpen open,
    BuyRequest request,
    BuyQuote quote, {
    BuyReviewNotice? notice,
    bool confirming = false,
  }) => page(
    _orderKey,
    Builder(
      builder: (context) => QuoteReviewPage(
        title: context.loc.buyConfirmTitle,
        rows: buyReviewRows(context, open, request, quote.quoted.order, unit),
        deadline: quote.quoted.order.confirmationDeadline,
        refreshLabel: context.loc.buyConfirmAwaitingConfirmation,
        details: [
          if (notice != null)
            Text(
              switch (notice) {
                BuyQuoteLapsed() => context.loc.buyQuoteExpiredError,
                BuyConfirmNotApplied(:final problem) => problem.toTranslated(
                  context,
                ),
                BuyConfirmGateRefused(:final refusal) => refusal.toTranslated(
                  context,
                ),
              },
              style: TextStyle(color: context.appColors.error),
              textAlign: TextAlign.center,
            ),
        ],
        status: quote.status,
        canConfirm: !confirming,
        onConfirm: () => onEvent(BuyConfirmPressed(now())),
        onRetry: () => onEvent(const BuyRetryPressed()),
        onBack: () => onEvent(const BuyBackPressed()),
      ),
    ),
  );

  return switch (state) {
    BuyLoading(load: ContextFailed(:final problem)) => [
      status(
        _entryKey,
        message: (context) => problem.toTranslated(context),
        isError: true,
        actions: (context) => [retry(context), back(context)],
      ),
    ],
    BuyLoading() => [status(_entryKey, busy: true)],
    final BuyEntry entry => entryPages(entry),
    BuyOrdering(:final open, :final request, :final order) => [
      entryUnder(open, request),
      switch (order) {
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
              () => onEvent(const BuyRetryPressed()),
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
        OrderQuoted() ||
        OrderPlaced() ||
        OrderCommitted() ||
        OrderSessionEnded() ||
        OrderAmountRefused() ||
        OrderLeft() => status(_orderKey, busy: true),
      },
    ],
    BuyReview(:final open, :final request, :final quote, :final notice) => [
      entryUnder(open, request),
      review(open, request, quote, notice: notice),
    ],
    BuyConfirming(:final open, :final request, :final confirm) => [
      entryUnder(open, request),
      switch (confirm) {
        ConfirmWriteRefused(:final refusal) => status(
          _confirmKey,
          message: (context) => refusal.toTranslated(context),
          isError: true,
          actions: (context) => [retry(context), back(context)],
        ),
        ConfirmFailed(:final problem) => status(
          _confirmKey,
          message: (context) => problem.toTranslated(context),
          isError: true,
          actions: (context) => [retry(context), back(context)],
        ),
        ConfirmUnverified(:final problem) => status(
          _confirmKey,
          headline: (context) => context.loc.exchangeStepUnverified,
          message: (context) => problem.toTranslated(context),
          isError: true,
          actions: (context) => [
            FlowAction(
              context.loc.exchangeStepCheckAgain,
              () => onEvent(const BuyRetryPressed()),
            ),
            FlowAction(
              context.loc.exchangePaymentSentLeave,
              () => onEvent(const BuyBackPressed()),
              primary: false,
            ),
          ],
        ),
        ConfirmVerifying() => status(
          _confirmKey,
          message: (context) => context.loc.exchangeStepVerifying,
          busy: true,
        ),
        ConfirmConfirming() ||
        ConfirmConfirmed() ||
        ConfirmSessionEnded() ||
        ConfirmLeft() => status(
          _confirmKey,
          message: (context) => context.loc.buyConfirmAwaitingConfirmation,
          busy: true,
        ),
      },
    ],
    final BuyDone done => [
      page(
        _endKey,
        Builder(
          builder: (context) => BuyDonePage(
            done: done,
            unit: unit,
            now: now,
            onClose: () => onEvent(const BuyDonePressed()),
            openOrder: (orderId) => ui.openOrder(context, orderId),
            showPaymentAnimations: ui.showPaymentAnimations,
            onAccelerate: (orderId) => context.pushNamed(
              BuyRoute.buyAccelerate.name,
              pathParameters: {'orderId': orderId},
            ),
          ),
        ),
      ),
    ],
    BuySessionEnded() => [
      status(
        _endKey,
        message: (context) => context.loc.exchangeFlowSessionEnded,
        isError: true,
        actions: (context) => [
          FlowAction(
            context.loc.closeDialogButton,
            () => onEvent(const BuyDonePressed()),
          ),
        ],
      ),
    ],
    BuyClosed() => [status(_endKey, busy: true)],
  };
}

/// The review rows: what is paid, received, at what price, and where to.
List<(String, String)> buyReviewRows(
  BuildContext context,
  BuyOpen open,
  BuyRequest request,
  BuyOrder order,
  BitcoinUnit unit,
) {
  final wallet = switch (request.walletId) {
    final id? => open.context.walletOf(id),
    null => null,
  };
  final rate =
      order.exchangeRateAmount ??
      (order.payoutAmount > 0 ? order.payinAmount / order.payoutAmount : 0.0);
  return [
    (
      context.loc.buyConfirmYouPay,
      FormatAmount.fiat(order.payinAmount, order.payinCurrency),
    ),
    (context.loc.buyConfirmYouReceive, formatBuyBitcoin(order, unit)),
    (
      context.loc.buyConfirmBitcoinPrice,
      FormatAmount.fiat(
        rate,
        order.exchangeRateCurrency ?? order.payinCurrency,
      ),
    ),
    (
      context.loc.buyConfirmPayoutWallet,
      wallet?.displayLabel(context) ?? context.loc.buyConfirmExternalWallet,
    ),
    (
      context.loc.buyConfirmPayoutMethod,
      buyPayoutMethodLabel(
        context,
        isLiquid: request.network == BtcNetwork.liquid,
      ),
    ),
  ];
}

String formatBuyBitcoin(BuyOrder order, BitcoinUnit unit) =>
    unit == BitcoinUnit.sats
    ? FormatAmount.sats(ConvertAmount.btcToSats(order.payoutAmount))
    : FormatAmount.btc(order.payoutAmount);
