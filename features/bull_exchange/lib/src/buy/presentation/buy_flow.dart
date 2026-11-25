import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Failure;

/// The buy flow (composition §5, Buy column): session → account and wallets
/// → amount from a funded balance (KYC and funding detours come back to the
/// same draft) with the payout destination beside it → order create + quote
/// → server confirm → outcome watch of the payout. Every state holds the
/// session it opened with and only the data valid in it; each step's output
/// is the next step's input, so none can be skipped.
@immutable
sealed class BuyFlowState {
  const BuyFlowState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is BuyFlowState &&
      other.runtimeType == runtimeType &&
      _listEquals(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));

  @override
  String toString() => '$runtimeType';
}

bool _listEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// An app wallet a buy can pay out to (the app's Bitcoin or Liquid wallets,
/// never the exchange default wallets: bd t-54y).
@immutable
final class BuyPayoutWallet {
  final String walletId;
  final BtcNetwork rail;
  final String? label;

  /// One of the app's wallets created at setup.
  final bool isDefault;

  /// On-chain with a local signer: it can receive the payout through a
  /// payjoin.
  final bool canPayjoin;

  const BuyPayoutWallet({
    required this.walletId,
    required this.rail,
    this.label,
    this.isDefault = false,
    this.canPayjoin = false,
  });

  DestinationOptionAppWallet get option =>
      DestinationOptionAppWallet(walletId, rail);

  @override
  bool operator ==(Object other) =>
      other is BuyPayoutWallet &&
      other.walletId == walletId &&
      other.rail == rail &&
      other.label == label &&
      other.isDefault == isDefault &&
      other.canPayjoin == canPayjoin;

  @override
  int get hashCode => Object.hash(walletId, rail, label, isDefault, canPayjoin);
}

/// The picked app wallet gave no receive address.
final class BuyReceiveAddressUnavailable extends Failure {
  const BuyReceiveAddressUnavailable();
}

/// The typed text is not a bitcoin address a buy can pay out to.
final class BuyAddressInvalid extends Failure {
  const BuyAddressInvalid();
}

/// What the flow loads before the amount: the account, the wallets it can
/// pay out to, whether payjoin may be offered, and the open journal entries
/// (a confirm whose outcome is still unknown starts in Verifying).
@immutable
final class BuyContext {
  final UserSummary summary;
  final List<BuyPayoutWallet> wallets;

  /// The app's payjoin policy allows buys.
  final bool payjoinAllowed;
  final List<UnknownWrite> openEntries;

  const BuyContext({
    required this.summary,
    required this.wallets,
    required this.payjoinAllowed,
    required this.openEntries,
    this.limits = const {},
  });

  /// The order limits the exchange answered in this flow, per currency:
  /// the amount step checks them before the next order.
  final Map<FiatCurrency, AmountLimits> limits;

  AmountContext get amountContext => AmountContext(
    kycGroups: summary.kycGroups,
    balances: {
      for (final balance in summary.balances)
        if (ExchangeCatalog.parse(balance.currencyCode) case KnownCurrency(
          :final market,
        ))
          market.currency: balance.amount,
    },
    limits: limits,
  );

  /// This context, knowing the order limit the exchange refused for.
  BuyContext withExchangeLimit(ExchangeOrderLimit limit) => BuyContext(
    summary: summary,
    wallets: wallets,
    payjoinAllowed: payjoinAllowed,
    openEntries: openEntries,
    limits: amountContext.withExchangeLimit(limit).limits,
  );

  Market? get preferredMarket => switch (summary.currency) {
    final code? => switch (ExchangeCatalog.parse(code)) {
      KnownCurrency(:final market) => market,
      UnknownCurrency() => null,
    },
    null => null,
  };

  /// Payjoin can be offered at all: the policy and the account allow it.
  bool get offersPayjoin => payjoinAllowed && summary.payjoinReceiveEnabled;

  List<DestinationOption> get options => [
    for (final wallet in wallets) wallet.option,
  ];

  BuyPayoutWallet? walletOf(String walletId) {
    for (final wallet in wallets) {
      if (wallet.walletId == walletId) return wallet;
    }
    return null;
  }

  /// The wallet picked when the flow opens: the one Liquid wallet created at
  /// setup, else the first wallet; none (external) when several Liquid
  /// setup wallets conflict.
  BuyPayoutWallet? get initialWallet {
    final liquidDefaults = [
      for (final wallet in wallets)
        if (wallet.isDefault && wallet.rail == BtcNetwork.liquid) wallet,
    ];
    return switch (liquidDefaults) {
      [final wallet] => wallet,
      [] => wallets.isEmpty ? null : wallets.first,
      // Two Liquid defaults: no single one to preselect.
      [_, _, ...] => null,
    };
  }

  BuyContext withAccount(BuyContext loaded) => BuyContext(
    summary: loaded.summary,
    wallets: wallets,
    payjoinAllowed: payjoinAllowed,
    openEntries: loaded.openEntries,
    limits: limits,
  );

  @override
  bool operator ==(Object other) =>
      other is BuyContext &&
      other.summary == summary &&
      _listEquals(other.wallets, wallets) &&
      other.payjoinAllowed == payjoinAllowed &&
      identical(other.openEntries, openEntries) &&
      _sameLimits(other.limits, limits);

  @override
  int get hashCode => Object.hash(
    summary,
    Object.hashAll(wallets),
    payjoinAllowed,
    openEntries.length,
  );
}

/// What every state after the account load holds.
@immutable
final class BuyOpen {
  final ExchangeSession session;
  final BuyContext context;

  const BuyOpen(this.session, this.context);

  @override
  bool operator ==(Object other) =>
      other is BuyOpen && other.session == session && other.context == context;

  @override
  int get hashCode => Object.hash(session, context);
}

const _satsPerBitcoin = 100000000;

/// The order create the flow sends: the entered amount, paid out to the
/// picked destination, through a payjoin receiver on [payjoinWalletId] when
/// there is one.
@immutable
final class BuyRequest {
  final EnteredAmount amount;
  final Destination destination;

  /// The user's payjoin switch, kept for going back to the entry.
  final bool payjoinChosen;

  /// The app wallet a payjoin receiver is started on; null for a plain
  /// payout.
  final String? payjoinWalletId;

  const BuyRequest({
    required this.amount,
    required this.destination,
    required this.payjoinChosen,
    this.payjoinWalletId,
  });

  OrderAmount get orderAmount => switch (amount.enteredIn) {
    AmountUnit.fiat => FiatAmount(amount.fiat),
    AmountUnit.bitcoin => BitcoinAmount(amount.sats / _satsPerBitcoin),
  };

  FiatCurrency get currency => amount.market.currency;

  BtcNetwork get network => destination.rail;

  /// The app wallet the payout goes to; null for a typed address.
  String? get walletId => switch (destination) {
    DestinationAppWallet(:final walletId) => walletId,
    DestinationDefaultWallet() || DestinationAddress() => null,
  };

  /// What the journal records when the create's outcome is unknown.
  OrderCreateJournalRequest get journal => OrderCreateJournalRequest(
    type: OrderType.buy,
    amount: orderAmount,
    currency: currency,
  );

  @override
  bool operator ==(Object other) =>
      other is BuyRequest &&
      other.amount == amount &&
      other.destination == destination &&
      other.payjoinChosen == payjoinChosen &&
      other.payjoinWalletId == payjoinWalletId;

  @override
  int get hashCode =>
      Object.hash(amount, destination, payjoinChosen, payjoinWalletId);
}

/// The quoted order the server confirm confirms.
@immutable
final class BuyConfirmTarget {
  final BuyOrder order;

  const BuyConfirmTarget(this.order);

  @override
  bool operator ==(Object other) =>
      other is BuyConfirmTarget && other.order.orderId == order.orderId;

  @override
  int get hashCode => Object.hash(BuyConfirmTarget, order.orderId);
}

/// Buy's amount policy: a funded balance's currency, fiat or bitcoin, the
/// KYC level checked, and an amount over the balance offers funding.
const buyAmountPolicy = AmountPolicy(
  currencySource: CurrencyFromFundedBalances(),
  allowBitcoinUnit: true,
  checkBalance: true,
  onShortfall: BalanceShortfall.offerFunding,
  checkKyc: true,
  withDescription: false,
);

/// The destination pick: an app wallet (its receive address read when
/// picked) or a typed external bitcoin address.
final buyDestinationPolicy = destinationPolicy(acceptsTyped: true);

String _buyOrderId(BuyOrder order) => order.orderId;

/// A buy order holds a price lock until it is confirmed.
const buyOrderPolicy = OrderPolicy<BuyOrder>(idOf: _buyOrderId, locks: true);

String _buyTargetId(BuyConfirmTarget target) => target.order.orderId;

const buyConfirmPolicy = ServerConfirmPolicy<BuyConfirmTarget>(
  writeKind: FinancialWriteKind.orderConfirm,
  journalKind: UnknownWriteKind.buyConfirm,
  resourceIdOf: _buyTargetId,
);

/// A confirmed buy is done once its payout completed, failed once the order
/// or the payout ended otherwise.
OutcomeVerdict buyPayoutVerdict(BuyOrder order) {
  if (order.payoutStatus == OrderPayoutStatus.completed) {
    return OutcomeVerdict.done;
  }
  final ended = switch (order.orderStatus) {
    OrderStatus.canceled ||
    OrderStatus.expired ||
    OrderStatus.orderExpired ||
    OrderStatus.rejected ||
    OrderStatus.failed => true,
    OrderStatus.inProgress ||
    OrderStatus.awaitingConfirmation ||
    OrderStatus.completed ||
    OrderStatus.unknown => false,
  };
  return ended || order.payoutStatus.isTerminal
      ? OutcomeVerdict.failed
      : OutcomeVerdict.pending;
}

bool _noReceipt(BuyOrder order) => false;

/// The payout watch: every 5 s while visible, for at most 10 minutes; after
/// that, or after 5 failed reads in a row, the user checks again.
const buyOutcomePolicy = OutcomePolicy<BuyOrder>(
  idOf: _buyOrderId,
  verdictOf: buyPayoutVerdict,
  hasReceipt: _noReceipt,
  maxPolls: 120,
  maxDuration: Duration(minutes: 10),
  maxUnreadable: 5,
);

/// The re-read of a buy whose confirm outcome is unknown: in progress or
/// completed means it was confirmed; awaiting confirmation or ended means
/// not; an unknown status can't tell.
ConfirmCheck<BuyOrder> buyConfirmCheck(ExchangeRead<Order> read) =>
    switch (read) {
      ReadGot(value: final BuyOrder order) => switch (order.orderStatus) {
        OrderStatus.inProgress ||
        OrderStatus.completed => ConfirmSeenApplied(order),
        OrderStatus.awaitingConfirmation ||
        OrderStatus.canceled ||
        OrderStatus.expired ||
        OrderStatus.orderExpired ||
        OrderStatus.rejected ||
        OrderStatus.failed => const ConfirmSeenNotApplied(),
        OrderStatus.unknown => const ConfirmCheckFailed(ReadProblemMalformed()),
      },
      ReadGot() => const ConfirmCheckFailed(ReadProblemMalformed()),
      ReadSessionRejected() => const ConfirmCheckSessionRejected(),
      ReadMissing() ||
      ReadUnreachable() ||
      ReadMalformed() => ConfirmCheckFailed(ReadProblem.of(read)!),
    };

typedef BuyDestinationState = PickState<DestinationOption, Destination>;
typedef BuyDestinationEvent = PickEvent<DestinationOption, Destination>;
typedef BuyOrderState = OrderStepState<BuyRequest, BuyOrder>;
typedef BuyOrderEvent = OrderStepEvent<BuyRequest, BuyOrder>;
typedef BuyQuote = OrderQuoted<BuyRequest, BuyOrder>;
typedef BuyConfirmState = ServerConfirmState<BuyConfirmTarget, BuyOrder>;
typedef BuyConfirmEvent = ServerConfirmEvent<BuyConfirmTarget, BuyOrder>;

/// Why the review is shown again; cleared by the next Confirm.
@immutable
sealed class BuyReviewNotice {
  const BuyReviewNotice();
}

/// Confirm was pressed on a price whose lock had lapsed: a new one loads.
final class BuyQuoteLapsed extends BuyReviewNotice {
  const BuyQuoteLapsed();

  @override
  bool operator ==(Object other) => other is BuyQuoteLapsed;

  @override
  int get hashCode => (BuyQuoteLapsed).hashCode;
}

/// The confirm did not take effect (refused, not sent, or a re-read showed
/// it was not applied); a fresh quote can be confirmed.
final class BuyConfirmNotApplied extends BuyReviewNotice {
  final WriteProblem problem;

  const BuyConfirmNotApplied(this.problem);

  @override
  bool operator ==(Object other) =>
      other is BuyConfirmNotApplied && other.problem == problem;

  @override
  int get hashCode => Object.hash(BuyConfirmNotApplied, problem);
}

/// The account's write gate refused the confirm; nothing was sent.
final class BuyConfirmGateRefused extends BuyReviewNotice {
  final WriteGateRefusal refusal;

  const BuyConfirmGateRefused(this.refusal);

  @override
  bool operator ==(Object other) =>
      other is BuyConfirmGateRefused && other.refusal == refusal;

  @override
  int get hashCode => Object.hash(BuyConfirmGateRefused, refusal);
}

/// Reading the account and the wallets. Its failure has a Retry.
final class BuyLoading extends BuyFlowState {
  final ExchangeSession session;

  /// [ContextLoading] or [ContextFailed].
  final ContextLoadState<BuyContext> load;

  const BuyLoading(this.session, this.load);

  @override
  List<Object?> get _props => [session, load];
}

/// The amount and, beside it, where the bitcoin goes.
final class BuyEntry extends BuyFlowState {
  final BuyOpen open;

  /// Never [AmountDone] or [AmountSessionRejected]: those leave the entry.
  final AmountEntryState amount;
  final BuyDestinationState destination;

  /// The user's payjoin switch (shown only where payjoin can be offered).
  final bool payjoin;

  const BuyEntry(this.open, this.amount, this.destination, this.payjoin);

  /// The wallet the destination names, picked or being resolved.
  BuyPayoutWallet? get selectedWallet => switch (destination) {
    PickResolving(option: DestinationOptionAppWallet(:final walletId)) ||
    PickChosen(value: DestinationAppWallet(:final walletId)) ||
    PickChoosing(
      problem: PickResolveFailed(
        option: DestinationOptionAppWallet(:final walletId),
      ),
    ) => open.context.walletOf(walletId),
    PickResolving() ||
    PickChosen() ||
    PickChoosing() ||
    PickValidating() => null,
  };

  /// Payjoin can be offered for the selected wallet.
  bool get offersPayjoin =>
      open.context.offersPayjoin && (selectedWallet?.canPayjoin ?? false);

  @override
  List<Object?> get _props => [open, amount, destination, payjoin];
}

/// Creating the buy order through the write gate.
final class BuyOrdering extends BuyFlowState {
  final BuyOpen open;
  final BuyRequest request;

  /// [OrderCreating], [OrderWriteRefused], [OrderCreateFailed],
  /// [OrderVerifying] or [OrderUnverified].
  final BuyOrderState order;

  const BuyOrdering(this.open, this.request, this.order);

  @override
  List<Object?> get _props => [open, request, order];
}

/// The quoted order, its price lock kept fresh, waiting for Confirm.
final class BuyReview extends BuyFlowState {
  final BuyOpen open;
  final BuyRequest request;
  final BuyQuote quote;
  final BuyReviewNotice? notice;

  const BuyReview(this.open, this.request, this.quote, {this.notice});

  BuyOrder get order => quote.quoted.order;

  @override
  List<Object?> get _props => [open, request, quote, notice];
}

/// Confirming the order: the money-moving write. Never offers it twice
/// while its outcome may be unknown; Back is answered only once nothing is
/// in flight.
final class BuyConfirming extends BuyFlowState {
  final BuyOpen open;
  final BuyRequest request;
  final BuyOrder order;

  /// [ConfirmConfirming], [ConfirmVerifying] or [ConfirmUnverified]: a
  /// refused or failed confirm goes back to the review.
  final BuyConfirmState confirm;

  const BuyConfirming(this.open, this.request, this.order, this.confirm);

  @override
  List<Object?> get _props => [open, request, order.orderId, confirm];
}

/// The exchange confirmed the order; the payout is watched.
final class BuyDone extends BuyFlowState {
  final BuyOpen open;
  final BuyRequest request;

  /// Never [WatchSessionEnded] or [WatchLeft].
  final OutcomeWatchState<BuyOrder> watch;

  const BuyDone(this.open, this.request, this.watch);

  /// The latest order the watch read.
  BuyOrder get order => switch (watch) {
    WatchWatching(:final order) ||
    WatchPaused(:final order) ||
    WatchDone(:final order) ||
    WatchReceipt(:final order) ||
    WatchFailed(:final order) ||
    WatchUnreadable(:final order) ||
    WatchTimedOut(:final order) => order,
    WatchSessionEnded() || WatchLeft() => throw StateError('watch ended'),
  };

  @override
  List<Object?> get _props => [open, request, watch];
}

/// The session the flow opened with ended. The only exit is Close.
final class BuySessionEnded extends BuyFlowState {
  const BuySessionEnded();

  @override
  List<Object?> get _props => const [];
}

/// The user left the flow; [bought] after a confirmed order.
final class BuyClosed extends BuyFlowState {
  final bool bought;

  const BuyClosed({this.bought = false});

  @override
  List<Object?> get _props => [bought];
}

@immutable
sealed class BuyFlowEvent {
  const BuyFlowEvent();
}

final class BuyContextLoaded extends BuyFlowEvent {
  final int attempt;
  final ExchangeRead<BuyContext> read;

  const BuyContextLoaded(this.attempt, this.read);
}

/// Retry of whatever failed on screen: the load, the create, the quote, the
/// confirm's re-read or the payout watch.
final class BuyRetryPressed extends BuyFlowEvent {
  const BuyRetryPressed();
}

final class BuyAmountChanged extends BuyFlowEvent {
  final AmountEntryEvent event;

  const BuyAmountChanged(this.event);
}

/// The payout wallet dropdown: an app wallet, or null for an external
/// address.
final class BuyDestinationPicked extends BuyFlowEvent {
  final DestinationOptionAppWallet? option;

  const BuyDestinationPicked(this.option);
}

/// The external address field changed.
final class BuyAddressTyped extends BuyFlowEvent {
  final String text;

  const BuyAddressTyped(this.text);
}

/// An answer of the destination pick's lookup or validation.
final class BuyDestinationChanged extends BuyFlowEvent {
  final BuyDestinationEvent event;

  const BuyDestinationChanged(this.event);
}

final class BuyPayjoinToggled extends BuyFlowEvent {
  final bool enabled;

  const BuyPayjoinToggled(this.enabled);
}

final class BuyContinuePressed extends BuyFlowEvent {
  const BuyContinuePressed();
}

/// Back from the KYC web view; the account is read again.
final class BuyKycReturned extends BuyFlowEvent {
  const BuyKycReturned();
}

/// Back from funding the account; the account is read again.
final class BuyFundingReturned extends BuyFlowEvent {
  const BuyFundingReturned();
}

/// The account read after a detour.
final class BuyDetourLoaded extends BuyFlowEvent {
  final ExchangeRead<BuyContext> read;

  const BuyDetourLoaded(this.read);
}

final class BuyOrderChanged extends BuyFlowEvent {
  final BuyOrderEvent event;

  const BuyOrderChanged(this.event);
}

/// Confirm on the review, at [at]: a price whose lock has lapsed by then is
/// refreshed, never confirmed.
final class BuyConfirmPressed extends BuyFlowEvent {
  final DateTime at;

  const BuyConfirmPressed(this.at);
}

final class BuyConfirmChanged extends BuyFlowEvent {
  final BuyConfirmEvent event;

  const BuyConfirmChanged(this.event);
}

final class BuyWatchChanged extends BuyFlowEvent {
  final OutcomeWatchEvent<BuyOrder> event;

  const BuyWatchChanged(this.event);
}

/// App bar, system Back or a page the user removed.
final class BuyBackPressed extends BuyFlowEvent {
  const BuyBackPressed();
}

final class BuyDonePressed extends BuyFlowEvent {
  const BuyDonePressed();
}

/// The flow's screen became visible or hidden (route, app lifecycle).
final class BuyVisibilityChanged extends BuyFlowEvent {
  final bool visible;

  const BuyVisibilityChanged({required this.visible});
}

/// The signed-in session changed; null when signed out.
final class BuySessionChanged extends BuyFlowEvent {
  final ExchangeSession? session;

  const BuySessionChanged(this.session);
}

@immutable
sealed class BuyFlowEffect {
  const BuyFlowEffect();
}

final class BuyLoadContext extends BuyFlowEffect {
  final int attempt;

  const BuyLoadContext(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is BuyLoadContext && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(BuyLoadContext, attempt);
}

/// Read the account again after a detour; answer [BuyDetourLoaded].
final class BuyReloadForDetour extends BuyFlowEffect {
  const BuyReloadForDetour();

  @override
  bool operator ==(Object other) => other is BuyReloadForDetour;

  @override
  int get hashCode => (BuyReloadForDetour).hashCode;
}

final class BuyFetchRate extends BuyFlowEffect {
  final Market market;

  const BuyFetchRate(this.market);

  @override
  bool operator ==(Object other) =>
      other is BuyFetchRate && other.market == market;

  @override
  int get hashCode => Object.hash(BuyFetchRate, market);
}

final class BuyDestinationEffect extends BuyFlowEffect {
  final PickEffect<DestinationOption> effect;

  const BuyDestinationEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is BuyDestinationEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(BuyDestinationEffect, effect);
}

final class BuyOrderEffect extends BuyFlowEffect {
  final OrderStepEffect<BuyRequest> effect;

  const BuyOrderEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is BuyOrderEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(BuyOrderEffect, effect);
}

final class BuyConfirmEffect extends BuyFlowEffect {
  final ServerConfirmEffect<BuyConfirmTarget> effect;

  const BuyConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is BuyConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(BuyConfirmEffect, effect);
}

final class BuyWatchEffect extends BuyFlowEffect {
  final OutcomeWatchEffect effect;

  const BuyWatchEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is BuyWatchEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(BuyWatchEffect, effect);
}

/// The payout of [order] completed: label the completed order and sync the
/// app wallet it went to ([walletId], null for an external address).
final class BuyPayoutSettled extends BuyFlowEffect {
  final BuyOrder order;
  final String? walletId;

  const BuyPayoutSettled(this.order, this.walletId);

  @override
  bool operator ==(Object other) =>
      other is BuyPayoutSettled &&
      other.order.orderId == order.orderId &&
      other.walletId == walletId;

  @override
  int get hashCode => Object.hash(BuyPayoutSettled, order.orderId, walletId);
}

typedef BuyFlowNext = StepNext<BuyFlowState, BuyFlowEffect>;

const _ended = BuyFlowNext(BuySessionEnded());
const _closed = BuyFlowNext(BuyClosed());

/// The flow for [session]; without a signed-in session it has ended.
BuyFlowNext buyFlowStart(ExchangeSession? session) => switch (session) {
  final session? => BuyFlowNext(BuyLoading(session, const ContextLoading(1)), [
    const BuyLoadContext(1),
  ]),
  null => _ended,
};

BuyFlowNext transitionBuyFlow(BuyFlowState state, BuyFlowEvent event) {
  if (event case BuySessionChanged(:final session)) {
    final current = _sessionOf(state);
    return current != null && current != session
        ? BuyFlowNext(const BuySessionEnded(), _stopsOf(state))
        : BuyFlowNext.stay(state);
  }
  return switch (state) {
    BuyLoading() => _loading(state, event),
    BuyEntry() => _entry(state, event),
    BuyOrdering() => _ordering(state, event),
    BuyReview() => _review(state, event),
    BuyConfirming() => _confirming(state, event),
    BuyDone() => _done(state, event),
    BuySessionEnded() => _sessionEnded(state, event),
    BuyClosed() => BuyFlowNext.stay(state),
  };
}

ExchangeSession? _sessionOf(BuyFlowState state) => switch (state) {
  BuyLoading(:final session) => session,
  BuyEntry(:final open) ||
  BuyOrdering(:final open) ||
  BuyReview(:final open) ||
  BuyConfirming(:final open) ||
  BuyDone(:final open) => open.session,
  BuySessionEnded() || BuyClosed() => null,
};

/// What leaving [state] for good stops: the quote's timers and its payjoin
/// receiver, or the payout watch.
List<BuyFlowEffect> _stopsOf(BuyFlowState state) => switch (state) {
  BuyReview(:final quote) => [
    BuyOrderEffect(OrderStopTimers(quote.quoted.id)),
    BuyOrderEffect(OrderRelease(quote.quoted.id)),
  ],
  BuyDone(:final order) => [BuyWatchEffect(WatchStop(order.orderId))],
  BuyLoading() ||
  BuyEntry() ||
  BuyOrdering() ||
  BuyConfirming() ||
  BuySessionEnded() ||
  BuyClosed() => const [],
};

/// A step's answer [next] to the flow: a stay of the step is a stay of the
/// flow (same instance, no effects).
BuyFlowNext _stepped<S, F>(
  BuyFlowState flow,
  StepNext<S, F> next,
  S current,
  BuyFlowNext Function(StepNext<S, F> next) map,
) => identical(next.state, current) && next.effects.isEmpty
    ? BuyFlowNext.stay(flow)
    : map(next);

BuyFlowNext _loading(BuyLoading state, BuyFlowEvent event) {
  final ContextLoadEvent<BuyContext> loadEvent;
  switch (event) {
    case BuyContextLoaded(:final attempt, :final read):
      loadEvent = ContextLoaded(attempt, read);
    case BuyRetryPressed():
      loadEvent = const ContextRetryPressed();
    case BuyBackPressed() || BuyDonePressed():
      return _closed;
    case BuyAmountChanged() ||
        BuyDestinationPicked() ||
        BuyAddressTyped() ||
        BuyDestinationChanged() ||
        BuyPayjoinToggled() ||
        BuyContinuePressed() ||
        BuyKycReturned() ||
        BuyFundingReturned() ||
        BuyDetourLoaded() ||
        BuyOrderChanged() ||
        BuyConfirmPressed() ||
        BuyConfirmChanged() ||
        BuyWatchChanged() ||
        BuyVisibilityChanged() ||
        BuySessionChanged():
      return BuyFlowNext.stay(state);
  }
  final next = transitionContextLoad(state.load, loadEvent);
  if (identical(next.state, state.load)) return BuyFlowNext.stay(state);
  return switch (next.state) {
    ContextReady(:final context) => _opened(BuyOpen(state.session, context)),
    ContextSessionRejected() => _ended,
    ContextLoading() || ContextFailed() => BuyFlowNext(
      BuyLoading(state.session, next.state),
      [
        for (final effect in next.effects)
          switch (effect) {
            ContextFetch(:final attempt) => BuyLoadContext(attempt),
          },
      ],
    ),
  };
}

/// The entry as the flow opens: the preferred market's rate loading, and
/// the initial wallet's receive address being read.
BuyFlowNext _opened(BuyOpen open) {
  final start = pickStart<DestinationOption, Destination>(open.context.options);
  final initial = open.context.initialWallet;
  final destination = initial == null
      ? start
      : transitionPick(
          buyDestinationPolicy,
          start.state,
          PickChose<DestinationOption, Destination>(initial.option),
        );
  return _entryOf(
    open,
    amountEntryStart(
      buyAmountPolicy,
      open.context.amountContext,
      preferred: open.context.preferredMarket,
    ),
    destination,
    true,
  );
}

/// The entry after its amount answered [amount] and its destination
/// [destination]. An amount that is done leaves for the order only from
/// Continue ([_continue]).
BuyFlowNext _entryOf(
  BuyOpen open,
  AmountEntryNext amount,
  PickNext<DestinationOption, Destination> destination,
  bool payjoin,
) {
  final destinationEffects = [
    for (final effect in destination.effects) BuyDestinationEffect(effect),
  ];
  return switch (amount.state) {
    AmountSessionRejected() => _ended,
    AmountDone(amount: final entered) => BuyFlowNext(
      BuyEntry(
        open,
        AmountEditing(
          draft: entered.draft,
          quote: RateReady(entered.rate),
          context: open.context.amountContext,
        ),
        destination.state,
        payjoin,
      ),
      destinationEffects,
    ),
    AmountNoMarket() ||
    AmountEditing() ||
    AmountKycDetour() ||
    AmountFundingDetour() => BuyFlowNext(
      BuyEntry(open, amount.state, destination.state, payjoin),
      [
        for (final effect in amount.effects)
          ...switch (effect) {
            AmountFetchRate(:final market) => [BuyFetchRate(market)],
            // The shell opens the KYC web view and the funding flow on the
            // detour states; their return is BuyKycReturned /
            // BuyFundingReturned.
            AmountOpenKyc() || AmountOpenFunding() => const <BuyFlowEffect>[],
          },
        ...destinationEffects,
      ],
    ),
  };
}

BuyFlowNext _entryAmount(BuyEntry state, AmountEntryNext next) =>
    switch (next.state) {
      AmountDone(:final amount) => switch (state.destination) {
        PickChosen(value: final destination) => _toOrder(
          state,
          amount,
          destination,
        ),
        PickChoosing() ||
        PickResolving() ||
        PickValidating() => BuyFlowNext.stay(state),
      },
      AmountNoMarket() ||
      AmountEditing() ||
      AmountKycDetour() ||
      AmountFundingDetour() ||
      AmountSessionRejected() => _entryOf(
        state.open,
        next,
        PickNext<DestinationOption, Destination>(state.destination),
        state.payjoin,
      ),
    };

/// Continue: the amount is checked only once a destination is chosen.
BuyFlowNext _continue(BuyEntry state) => switch (state.destination) {
  PickChosen() => _stepped(
    state,
    transitionAmountEntry(
      buyAmountPolicy,
      state.amount,
      const AmountContinuePressed(),
    ),
    state.amount,
    (next) => _entryAmount(state, next),
  ),
  PickChoosing() ||
  PickResolving() ||
  PickValidating() => BuyFlowNext.stay(state),
};

BuyFlowNext _toOrder(
  BuyEntry state,
  EnteredAmount amount,
  Destination destination,
) {
  final wallet = switch (destination) {
    DestinationAppWallet(:final walletId) => state.open.context.walletOf(
      walletId,
    ),
    DestinationDefaultWallet() || DestinationAddress() => null,
  };
  final usesPayjoin =
      state.payjoin &&
      state.open.context.offersPayjoin &&
      wallet != null &&
      wallet.canPayjoin &&
      destination.rail == BtcNetwork.bitcoin;
  final request = BuyRequest(
    amount: amount,
    destination: destination,
    payjoinChosen: state.payjoin,
    payjoinWalletId: usesPayjoin ? wallet.walletId : null,
  );
  return _orderNext(
    state.open,
    request,
    orderCreateStart<BuyRequest, BuyOrder>(request),
  );
}

/// The destination pick after [event], from any of its states: a dropdown
/// change from a chosen value goes back to choosing first.
PickNext<DestinationOption, Destination> _pick(
  BuyDestinationState state,
  BuyDestinationEvent event,
) => transitionPick(buyDestinationPolicy, state, event);

PickNext<DestinationOption, Destination> _repick(
  BuyDestinationState state,
  BuyDestinationEvent event,
) => switch (state) {
  PickChosen() => _pick(_pick(state, const PickBackPressed()).state, event),
  PickChoosing() || PickResolving() || PickValidating() => _pick(state, event),
};

PickNext<DestinationOption, Destination>? _destinationPicked(
  BuyDestinationState state,
  DestinationOptionAppWallet? option,
) {
  if (option != null) {
    if (state case PickChosen(value: DestinationAppWallet(:final walletId))
        when walletId == option.walletId) {
      return null;
    }
    return _repick(state, PickChose(option));
  }
  return switch (state) {
    PickChosen(value: DestinationAppWallet()) ||
    PickResolving() => _pick(state, const PickBackPressed()),
    PickChoosing(problem: PickResolveFailed()) => PickNext(
      PickChoosing<DestinationOption, Destination>(state.options),
    ),
    PickChosen() || PickChoosing() || PickValidating() => null,
  };
}

PickNext<DestinationOption, Destination>? _addressTyped(
  BuyDestinationState state,
  String text,
) => switch (state) {
  PickChosen(value: DestinationAddress(:final address))
      when address == text.trim() =>
    null,
  PickChosen(value: DestinationAddress()) => _repick(state, PickTyped(text)),
  PickChoosing(problem: PickResolveFailed()) ||
  PickChosen() ||
  PickResolving() => null,
  PickChoosing() || PickValidating() => _pick(state, PickTyped(text)),
};

BuyFlowNext _withDestination(
  BuyEntry state,
  PickNext<DestinationOption, Destination>? next,
) =>
    next == null ||
        (identical(next.state, state.destination) && next.effects.isEmpty)
    ? BuyFlowNext.stay(state)
    : BuyFlowNext(
        BuyEntry(state.open, state.amount, next.state, state.payjoin),
        [for (final effect in next.effects) BuyDestinationEffect(effect)],
      );

BuyFlowNext _entry(BuyEntry state, BuyFlowEvent event) => switch (event) {
  BuyAmountChanged(event: AmountContinuePressed()) ||
  BuyContinuePressed() => _continue(state),
  BuyAmountChanged(:final event) => _stepped(
    state,
    transitionAmountEntry(buyAmountPolicy, state.amount, event),
    state.amount,
    (next) => _entryAmount(state, next),
  ),
  BuyDestinationPicked(:final option) => _withDestination(
    state,
    _destinationPicked(state.destination, option),
  ),
  BuyAddressTyped(:final text) => _withDestination(
    state,
    _addressTyped(state.destination, text),
  ),
  BuyDestinationChanged(:final event) => _withDestination(
    state,
    _pick(state.destination, event),
  ),
  BuyPayjoinToggled(:final enabled) =>
    enabled == state.payjoin
        ? BuyFlowNext.stay(state)
        : BuyFlowNext(
            BuyEntry(state.open, state.amount, state.destination, enabled),
          ),
  BuyKycReturned() => switch (state.amount) {
    AmountKycDetour() => _reload(state),
    AmountNoMarket() ||
    AmountEditing() ||
    AmountFundingDetour() ||
    AmountDone() ||
    AmountSessionRejected() => BuyFlowNext.stay(state),
  },
  BuyFundingReturned() => switch (state.amount) {
    AmountFundingDetour() || AmountNoMarket() => _reload(state),
    AmountKycDetour() ||
    AmountEditing() ||
    AmountDone() ||
    AmountSessionRejected() => BuyFlowNext.stay(state),
  },
  BuyDetourLoaded(:final read) => switch (state.amount) {
    AmountKycDetour() ||
    AmountFundingDetour() ||
    AmountNoMarket() => switch (read) {
      ReadGot(value: final loaded) => _detourReturned(
        state,
        BuyOpen(state.open.session, state.open.context.withAccount(loaded)),
      ),
      ReadSessionRejected() => _ended,
      // The detour page stays; returning again reads again.
      ReadMissing() ||
      ReadUnreachable() ||
      ReadMalformed() => BuyFlowNext.stay(state),
    },
    AmountEditing() ||
    AmountDone() ||
    AmountSessionRejected() => BuyFlowNext.stay(state),
  },
  BuyBackPressed() => switch (state.amount) {
    // Leaving a detour page re-checks the draft against what is known.
    AmountKycDetour() ||
    AmountFundingDetour() => _detourReturned(state, state.open),
    AmountNoMarket() ||
    AmountEditing() ||
    AmountDone() ||
    AmountSessionRejected() => _closed,
  },
  BuyContextLoaded() ||
  BuyRetryPressed() ||
  BuyOrderChanged() ||
  BuyConfirmPressed() ||
  BuyConfirmChanged() ||
  BuyWatchChanged() ||
  BuyDonePressed() ||
  BuyVisibilityChanged() ||
  BuySessionChanged() => BuyFlowNext.stay(state),
};

/// The same entry, with the account read again.
BuyFlowNext _reload(BuyEntry state) => BuyFlowNext(
  BuyEntry(state.open, state.amount, state.destination, state.payjoin),
  const [BuyReloadForDetour()],
);

BuyFlowNext _detourReturned(BuyEntry state, BuyOpen open) => _entryOf(
  open,
  transitionAmountEntry(
    buyAmountPolicy,
    state.amount,
    AmountDetourReturned(open.context.amountContext),
  ),
  PickNext<DestinationOption, Destination>(state.destination),
  state.payjoin,
);

/// [flow] with [effects] run before its own.
BuyFlowNext _led(List<BuyFlowEffect> effects, BuyFlowNext flow) =>
    effects.isEmpty
    ? flow
    : BuyFlowNext(flow.state, [...effects, ...flow.effects]);

/// Back to the entry with the draft, the destination and the switch kept.
/// The entry [request] was made from, as Back from the order shows it.
BuyEntry buyEntryUnder(BuyOpen open, BuyRequest request) =>
    _editEntry(open, request).state as BuyEntry;

/// The exchange refused [request]'s amount for [limit]: back to the entry
/// with the draft, the destination and the switch, the limit known to the
/// amount step from now on.
BuyFlowNext _amountRefused(
  BuyOpen open,
  BuyRequest request,
  ExchangeOrderLimit limit,
) {
  final learned = BuyOpen(open.session, open.context.withExchangeLimit(limit));
  return _entryOf(
    learned,
    transitionAmountEntry(
      buyAmountPolicy,
      AmountDone(request.amount, learned.context.amountContext),
      AmountLimitRefused(limit),
    ),
    PickNext<DestinationOption, Destination>(
      PickChosen<DestinationOption, Destination>(
        learned.context.options,
        request.destination,
      ),
    ),
    request.payjoinChosen,
  );
}

BuyFlowNext _editEntry(BuyOpen open, BuyRequest request) => _entryOf(
  open,
  transitionAmountEntry(
    buyAmountPolicy,
    AmountDone(request.amount, open.context.amountContext),
    const AmountEditRequested(),
  ),
  PickNext<DestinationOption, Destination>(
    PickChosen<DestinationOption, Destination>(
      open.context.options,
      request.destination,
    ),
  ),
  request.payjoinChosen,
);

BuyFlowNext _orderNext(
  BuyOpen open,
  BuyRequest request,
  OrderStepNext<BuyRequest, BuyOrder> next, {
  BuyReviewNotice? notice,
}) {
  final effects = [for (final effect in next.effects) BuyOrderEffect(effect)];
  return switch (next.state) {
    final BuyQuote quote => BuyFlowNext(
      BuyReview(open, request, quote, notice: notice),
      effects,
    ),
    OrderPlaced(:final placed) => BuyFlowNext(
      BuyReview(
        open,
        request,
        OrderQuoted<BuyRequest, BuyOrder>(placed, const QuoteLive()),
        notice: notice,
      ),
      effects,
    ),
    OrderCommitted(:final quoted) => _confirmNext(
      open,
      request,
      quoted.order,
      serverConfirmStart<BuyConfirmTarget, BuyOrder>(
        BuyConfirmTarget(quoted.order),
        openEntry: openEntryFor(
          buyConfirmPolicy,
          BuyConfirmTarget(quoted.order),
          open.context.openEntries,
        ),
      ),
      leading: effects,
    ),
    OrderLeft() => _led(effects, _editEntry(open, request)),
    // Retry would send the same amount: back to it, with the limit shown.
    OrderAmountRefused(:final limit) => _led(
      effects,
      _amountRefused(open, request, limit),
    ),
    OrderSessionEnded() => BuyFlowNext(const BuySessionEnded(), effects),
    OrderCreating() ||
    OrderWriteRefused() ||
    OrderCreateFailed() ||
    OrderVerifying() ||
    OrderUnverified() => BuyFlowNext(
      BuyOrdering(open, request, next.state),
      effects,
    ),
  };
}

BuyFlowNext _ordering(BuyOrdering state, BuyFlowEvent event) {
  final BuyOrderEvent stepEvent;
  switch (event) {
    case BuyOrderChanged(:final event):
      stepEvent = event;
    case BuyRetryPressed():
      stepEvent = const OrderRetryPressed();
    case BuyBackPressed():
      stepEvent = const OrderBackPressed();
    case BuyContextLoaded() ||
        BuyAmountChanged() ||
        BuyDestinationPicked() ||
        BuyAddressTyped() ||
        BuyDestinationChanged() ||
        BuyPayjoinToggled() ||
        BuyContinuePressed() ||
        BuyKycReturned() ||
        BuyFundingReturned() ||
        BuyDetourLoaded() ||
        BuyConfirmPressed() ||
        BuyConfirmChanged() ||
        BuyWatchChanged() ||
        BuyDonePressed() ||
        BuyVisibilityChanged() ||
        BuySessionChanged():
      return BuyFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionOrderStep(buyOrderPolicy, state.order, stepEvent),
    state.order,
    (next) => _orderNext(state.open, state.request, next),
  );
}

BuyFlowNext _review(BuyReview state, BuyFlowEvent event) {
  final BuyOrderEvent stepEvent;
  var notice = state.notice;
  switch (event) {
    case BuyOrderChanged(:final event):
      stepEvent = event;
    case BuyRetryPressed():
      stepEvent = const OrderRetryPressed();
    case BuyBackPressed():
      stepEvent = const OrderBackPressed();
    case BuyConfirmPressed(:final at):
      final deadline = state.order.confirmationDeadline;
      final lapsed = deadline != null && !at.isBefore(deadline);
      switch (state.quote.status) {
        case QuoteLive() when lapsed:
          stepEvent = OrderLockDue(state.quote.quoted.id);
          notice = const BuyQuoteLapsed();
        case QuoteLive():
          stepEvent = const OrderCommitPressed();
          notice = null;
        case QuoteRefreshing() || QuoteRetrying() || QuoteUnavailable():
          return BuyFlowNext.stay(state);
      }
    case BuyContextLoaded() ||
        BuyAmountChanged() ||
        BuyDestinationPicked() ||
        BuyAddressTyped() ||
        BuyDestinationChanged() ||
        BuyPayjoinToggled() ||
        BuyContinuePressed() ||
        BuyKycReturned() ||
        BuyFundingReturned() ||
        BuyDetourLoaded() ||
        BuyConfirmChanged() ||
        BuyWatchChanged() ||
        BuyDonePressed() ||
        BuyVisibilityChanged() ||
        BuySessionChanged():
      return BuyFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionOrderStep(buyOrderPolicy, state.quote, stepEvent),
    state.quote,
    (next) => _orderNext(state.open, state.request, next, notice: notice),
  );
}

/// The review again after a confirm that did not take effect: the quote
/// is refreshed (its timers stopped at Confirm) and [notice] says why.
BuyFlowNext _reviewAgain(
  BuyOpen open,
  BuyRequest request,
  BuyOrder order,
  BuyReviewNotice notice,
) => BuyFlowNext(
  BuyReview(
    open,
    request,
    OrderQuoted<BuyRequest, BuyOrder>(
      QuotedOrder(order.orderId, order),
      const QuoteRefreshing(0),
    ),
    notice: notice,
  ),
  [BuyOrderEffect(OrderRefresh(order.orderId))],
);

BuyFlowNext _confirmNext(
  BuyOpen open,
  BuyRequest request,
  BuyOrder order,
  ServerConfirmNext<BuyConfirmTarget, BuyOrder> next, {
  List<BuyFlowEffect> leading = const [],
}) {
  BuyFlowNext led(BuyFlowNext flow) => _led(leading, flow);
  return switch (next.state) {
    ConfirmConfirmed(:final confirmed) => led(
      _watchNext(
        open,
        request,
        outcomeWatchStart(buyOutcomePolicy, confirmed),
        settledBefore: false,
      ),
    ),
    ConfirmFailed(:final problem) => led(
      _reviewAgain(open, request, order, BuyConfirmNotApplied(problem)),
    ),
    ConfirmWriteRefused(:final refusal) => led(
      _reviewAgain(open, request, order, BuyConfirmGateRefused(refusal)),
    ),
    ConfirmSessionEnded() => led(_ended),
    // Only an unverified confirm is left, and it may have gone through:
    // the flow ends instead of offering the confirm again.
    ConfirmLeft() => led(_closed),
    ConfirmConfirming() ||
    ConfirmVerifying() ||
    ConfirmUnverified() => BuyFlowNext(
      BuyConfirming(open, request, order, next.state),
      [...leading, for (final effect in next.effects) BuyConfirmEffect(effect)],
    ),
  };
}

BuyFlowNext _confirming(BuyConfirming state, BuyFlowEvent event) {
  final BuyConfirmEvent stepEvent;
  switch (event) {
    case BuyConfirmChanged(:final event):
      stepEvent = event;
    case BuyRetryPressed():
      stepEvent = const ConfirmRetryPressed();
    case BuyBackPressed():
      stepEvent = const ConfirmBackPressed();
    case BuyContextLoaded() ||
        BuyAmountChanged() ||
        BuyDestinationPicked() ||
        BuyAddressTyped() ||
        BuyDestinationChanged() ||
        BuyPayjoinToggled() ||
        BuyContinuePressed() ||
        BuyKycReturned() ||
        BuyFundingReturned() ||
        BuyDetourLoaded() ||
        BuyOrderChanged() ||
        BuyConfirmPressed() ||
        BuyWatchChanged() ||
        BuyDonePressed() ||
        BuyVisibilityChanged() ||
        BuySessionChanged():
      return BuyFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionServerConfirm(buyConfirmPolicy, state.confirm, stepEvent),
    state.confirm,
    (next) => _confirmNext(state.open, state.request, state.order, next),
  );
}

bool _settled(OutcomeWatchState<BuyOrder> watch) => switch (watch) {
  WatchDone() || WatchReceipt() => true,
  WatchWatching() ||
  WatchPaused() ||
  WatchFailed() ||
  WatchUnreadable() ||
  WatchTimedOut() ||
  WatchSessionEnded() ||
  WatchLeft() => false,
};

BuyFlowNext _watchNext(
  BuyOpen open,
  BuyRequest request,
  OutcomeWatchNext<BuyOrder> next, {
  required bool settledBefore,
}) {
  final effects = [for (final effect in next.effects) BuyWatchEffect(effect)];
  return switch (next.state) {
    WatchSessionEnded() => BuyFlowNext(const BuySessionEnded(), effects),
    WatchLeft() => BuyFlowNext(const BuyClosed(bought: true), effects),
    WatchDone(:final order) || WatchReceipt(:final order) => BuyFlowNext(
      BuyDone(open, request, next.state),
      [
        ...effects,
        if (!settledBefore) BuyPayoutSettled(order, request.walletId),
      ],
    ),
    WatchWatching() ||
    WatchPaused() ||
    WatchFailed() ||
    WatchUnreadable() ||
    WatchTimedOut() => BuyFlowNext(BuyDone(open, request, next.state), effects),
  };
}

BuyFlowNext _done(BuyDone state, BuyFlowEvent event) {
  final OutcomeWatchEvent<BuyOrder> watchEvent;
  switch (event) {
    case BuyWatchChanged(:final event):
      watchEvent = event;
    case BuyRetryPressed():
      watchEvent = const WatchRetryPressed();
    case BuyVisibilityChanged(:final visible):
      watchEvent = WatchVisibilityChanged(visible: visible);
    case BuyDonePressed() || BuyBackPressed():
      return BuyFlowNext(const BuyClosed(bought: true), [
        BuyWatchEffect(WatchStop(state.order.orderId)),
      ]);
    case BuyContextLoaded() ||
        BuyAmountChanged() ||
        BuyDestinationPicked() ||
        BuyAddressTyped() ||
        BuyDestinationChanged() ||
        BuyPayjoinToggled() ||
        BuyContinuePressed() ||
        BuyKycReturned() ||
        BuyFundingReturned() ||
        BuyDetourLoaded() ||
        BuyOrderChanged() ||
        BuyConfirmPressed() ||
        BuyConfirmChanged() ||
        BuySessionChanged():
      return BuyFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionOutcomeWatch(buyOutcomePolicy, state.watch, watchEvent),
    state.watch,
    (next) => _watchNext(
      state.open,
      state.request,
      next,
      settledBefore: _settled(state.watch),
    ),
  );
}

BuyFlowNext _sessionEnded(BuySessionEnded state, BuyFlowEvent event) =>
    switch (event) {
      BuyDonePressed() || BuyBackPressed() => _closed,
      BuyContextLoaded() ||
      BuyRetryPressed() ||
      BuyAmountChanged() ||
      BuyDestinationPicked() ||
      BuyAddressTyped() ||
      BuyDestinationChanged() ||
      BuyPayjoinToggled() ||
      BuyContinuePressed() ||
      BuyKycReturned() ||
      BuyFundingReturned() ||
      BuyDetourLoaded() ||
      BuyOrderChanged() ||
      BuyConfirmPressed() ||
      BuyConfirmChanged() ||
      BuyWatchChanged() ||
      BuyVisibilityChanged() ||
      BuySessionChanged() => BuyFlowNext.stay(state),
    };

bool _sameLimits(
  Map<FiatCurrency, AmountLimits> a,
  Map<FiatCurrency, AmountLimits> b,
) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
