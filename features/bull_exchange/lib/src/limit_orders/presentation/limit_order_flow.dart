import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import '../domain/entities/limit_order_amount_limits.dart';

/// The limit-order create flow (composition §5, Limit column): session →
/// account load → intro → target price → destination → amount (limits from
/// the destination's rail) → review (rate read again) → server confirm of
/// `addLimitOrder` → done. Every state holds the session it opened with and
/// only the data valid in it; each step's output is the next step's input.
@immutable
sealed class LimitFlowState {
  const LimitFlowState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is LimitFlowState &&
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

/// An app wallet the bitcoin may go to; its receive address is read when
/// picked.
@immutable
final class LimitAppWallet {
  final String walletId;
  final BtcNetwork rail;
  final String? label;

  const LimitAppWallet(this.walletId, this.rail, {this.label});

  DestinationOption get option => DestinationOptionAppWallet(walletId, rail);

  @override
  bool operator ==(Object other) =>
      other is LimitAppWallet &&
      other.walletId == walletId &&
      other.rail == rail &&
      other.label == label;

  @override
  int get hashCode => Object.hash(walletId, rail, label);
}

/// What the flow loads first: the account (balances, currency, KYC groups),
/// the exchange default wallets, the app's own wallets of the environment
/// and the open journal entries, so a create whose outcome is still unknown
/// starts in Verifying instead of offering the write again.
@immutable
final class LimitOrderContext {
  final UserSummary summary;
  final DefaultWallets defaultWallets;
  final List<LimitAppWallet> appWallets;
  final List<UnknownWrite> openEntries;

  const LimitOrderContext(
    this.summary,
    this.defaultWallets,
    this.appWallets,
    this.openEntries,
  );

  /// The markets with a positive balance, in catalog order of the balances;
  /// a balance in a currency this build has no market for is not offered.
  List<Market> get fundedMarkets => [
    for (final balance in summary.balances)
      if (balance.amount > 0)
        if (ExchangeCatalog.parse(balance.currencyCode) case KnownCurrency(
          :final market,
        ))
          market,
  ];

  double balanceOf(Market market) => amountContext.balanceOf(market.currency);

  AmountContext get amountContext => AmountContext(
    kycGroups: summary.kycGroups,
    balances: {
      for (final balance in summary.balances)
        if (ExchangeCatalog.parse(balance.currencyCode) case KnownCurrency(
          :final market,
        ))
          market.currency: balance.amount,
    },
  );

  /// The account's own currency when it is funded, else the first funded.
  Market? get preferredMarket {
    final funded = fundedMarkets;
    if (funded.isEmpty) return null;
    final preferred = switch (ExchangeCatalog.parse(summary.currency ?? '')) {
      KnownCurrency(:final market) => market,
      UnknownCurrency() => null,
    };
    return funded.contains(preferred) ? preferred : funded.first;
  }

  /// Exchange default wallets (Bitcoin, Lightning, Liquid), then app wallets.
  List<DestinationOption> get destinationOptions => [
    for (final rail in const [
      BtcNetwork.bitcoin,
      BtcNetwork.lightning,
      BtcNetwork.liquid,
    ])
      if (defaultWallets.getWallet(rail)?.address case final address?
          when address.isNotEmpty)
        DestinationOptionDefaultWallet(rail, address),
    for (final wallet in appWallets) wallet.option,
  ];

  LimitAppWallet? appWallet(String walletId) {
    for (final wallet in appWallets) {
      if (wallet.walletId == walletId) return wallet;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is LimitOrderContext &&
      other.summary == summary &&
      identical(other.defaultWallets, defaultWallets) &&
      identical(other.appWallets, appWallets) &&
      identical(other.openEntries, openEntries);

  @override
  int get hashCode => Object.hash(summary, appWallets.length);
}

/// What every state after the account load holds.
@immutable
final class LimitOpen {
  final ExchangeSession session;
  final LimitOrderContext context;

  const LimitOpen(this.session, this.context);

  @override
  bool operator ==(Object other) =>
      other is LimitOpen &&
      other.session == session &&
      other.context == context;

  @override
  int get hashCode => Object.hash(session, context);
}

/// A target price and the rate it was set against, changed together: the
/// price is never shown under another currency's rate (LIM-1).
@immutable
final class PricedTarget {
  final Market market;
  final LimitOrderRate rate;
  final double limitPrice;

  /// Discount from the index price, 1–99 %.
  final double discount;

  const PricedTarget._(this.market, this.rate, this.limitPrice, this.discount);

  /// The target at 1 % under the index price of [rate].
  factory PricedTarget.at(Market market, LimitOrderRate rate) =>
      PricedTarget._(market, rate, rate.priceForDiscount(1), 1);

  PricedTarget withDiscount(double discount) {
    final clamped = discount.clamp(1, 99).toDouble();
    return PricedTarget._(
      market,
      rate,
      rate.priceForDiscount(clamped),
      clamped,
    );
  }

  PricedTarget withPrice(double price) {
    final clamped = price
        .clamp(rate.indexPrice * 0.01, rate.indexPrice * 0.99)
        .toDouble();
    return PricedTarget._(
      market,
      rate,
      clamped,
      rate.discountForPrice(clamped),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PricedTarget &&
      other.market == market &&
      other.rate.currencyCode == rate.currencyCode &&
      other.rate.indexPrice == rate.indexPrice &&
      other.rate.userPrice == rate.userPrice &&
      other.limitPrice == limitPrice &&
      other.discount == discount;

  @override
  int get hashCode =>
      Object.hash(market, rate.indexPrice, rate.userPrice, limitPrice);

  @override
  String toString() => 'PricedTarget($market, $limitPrice)';
}

/// The create the flow sends: the target, the destination and the amount.
@immutable
final class LimitOrderRequest {
  final PricedTarget target;
  final Destination destination;
  final EnteredAmount amount;

  const LimitOrderRequest(this.target, this.destination, this.amount);

  /// Valid by construction: the target price is 1–99 % of a positive index
  /// price, the amount is a parsed positive number and the address came from
  /// the pick.
  LimitOrderDraft get draft => LimitOrderDraft(
    limitPrice: target.limitPrice,
    fiatAmount: amount.fiat,
    currency: target.market.currency,
    address: destination.address,
  );

  @override
  bool operator ==(Object other) =>
      other is LimitOrderRequest &&
      other.target == target &&
      other.destination == destination &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(target, destination, amount);
}

/// The per-rail buy limits of [rail] as fiat bounds at [userPrice]
/// (on-chain and Liquid have a minimum, Lightning a maximum).
AmountLimits limitAmountLimits(BtcNetwork rail, double userPrice) {
  double fiatOf(int sats) =>
      sats / LimitOrderAmountLimits.satsPerBtc * userPrice;
  return switch (rail) {
    BtcNetwork.bitcoin => AmountLimits(
      minFiat: fiatOf(LimitOrderAmountLimits.minOnChainSats),
    ),
    BtcNetwork.liquid => AmountLimits(
      minFiat: fiatOf(LimitOrderAmountLimits.minLiquidSats),
    ),
    BtcNetwork.lightning => AmountLimits(
      maxFiat: fiatOf(LimitOrderAmountLimits.maxLightningSats),
    ),
  };
}

/// The amount rules of a limit order to [destination] at [target]: the
/// target's currency, fiat only, KYC checked (the server treats it as a
/// buy), over the balance is a warning (nothing is reserved), and the
/// destination rail's limits.
AmountPolicy limitAmountPolicy(PricedTarget target, Destination destination) =>
    AmountPolicy(
      currencySource: CurrencyFixed(target.market),
      allowBitcoinUnit: false,
      checkBalance: true,
      onShortfall: BalanceShortfall.warn,
      checkKyc: true,
      withDescription: false,
      limits: limitAmountLimits(destination.rail, target.rate.userPrice),
    );

String? _noResourceId(LimitOrderRequest _) => null;

/// A limit-order create is journaled without an order id: an open entry of
/// its kind starts the confirm in Verifying.
const limitOrderCreatePolicy = ServerConfirmPolicy<LimitOrderRequest>(
  writeKind: FinancialWriteKind.limitOrderCreate,
  journalKind: UnknownWriteKind.limitOrderCreate,
  resourceIdOf: _noResourceId,
);

/// What the re-read after an unknown create shows: the created order when
/// the recent orders hold it.
ConfirmCheck<LimitOrder> limitOrderCreateCheck(
  LimitOrderRequest request,
  ExchangeRead<List<LimitOrder>> recent,
) => switch (recent) {
  ReadGot(:final value) => switch (findCreatedLimitOrder(
    request.draft.journalRequest,
    value,
  )) {
    final order? => ConfirmSeenApplied(order),
    null => const ConfirmSeenNotApplied(),
  },
  ReadSessionRejected() => const ConfirmCheckSessionRejected(),
  ReadMissing() ||
  ReadUnreachable() ||
  ReadMalformed() => ConfirmCheckFailed(ReadProblem.of(recent)!),
};

const _destinationPolicy = PickPolicy<DestinationOption, Destination>(
  resolutionOf: destinationResolution,
  acceptsTyped: true,
);

typedef LimitPickState = PickState<DestinationOption, Destination>;
typedef LimitPickEvent = PickEvent<DestinationOption, Destination>;
typedef LimitConfirmState = ServerConfirmState<LimitOrderRequest, LimitOrder>;
typedef LimitConfirmEvent = ServerConfirmEvent<LimitOrderRequest, LimitOrder>;

/// The target price step, a flow-only step: the rate of the chosen market
/// and the price set against it.
@immutable
sealed class LimitTargetStep {
  const LimitTargetStep();

  int get attempt;
}

/// Reading the rate of [market]. [kept] is the target shown before a
/// currency switch; a failed switch goes back to it.
final class TargetLoading extends LimitTargetStep {
  final Market market;
  @override
  final int attempt;
  final PricedTarget? kept;

  const TargetLoading(this.market, this.attempt, {this.kept});

  @override
  bool operator ==(Object other) =>
      other is TargetLoading &&
      other.market == market &&
      other.attempt == attempt &&
      other.kept == kept;

  @override
  int get hashCode => Object.hash(TargetLoading, market, attempt, kept);
}

/// The first rate read failed: nothing to show; Retry reads again.
final class TargetFailed extends LimitTargetStep {
  final Market market;
  @override
  final int attempt;
  final ReadProblem problem;

  const TargetFailed(this.market, this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is TargetFailed &&
      other.market == market &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(TargetFailed, market, attempt, problem);
}

/// A priced target. [switchProblem] is why the last currency switch failed;
/// the target stayed on its own market.
final class TargetReady extends LimitTargetStep {
  final PricedTarget target;
  @override
  final int attempt;
  final ReadProblem? switchProblem;

  const TargetReady(this.target, this.attempt, {this.switchProblem});

  @override
  bool operator ==(Object other) =>
      other is TargetReady &&
      other.target == target &&
      other.attempt == attempt &&
      other.switchProblem == switchProblem;

  @override
  int get hashCode => Object.hash(TargetReady, target, attempt, switchProblem);
}

/// The rate read of the review, taken again on entering it (LIM-4).
@immutable
sealed class LimitReviewCheck {
  const LimitReviewCheck();
}

final class ReviewChecking extends LimitReviewCheck {
  const ReviewChecking();

  @override
  bool operator ==(Object other) => other is ReviewChecking;

  @override
  int get hashCode => (ReviewChecking).hashCode;
}

/// The target is under the index price: Confirm is offered.
final class ReviewLive extends LimitReviewCheck {
  final LimitOrderRate rate;

  const ReviewLive(this.rate);

  @override
  bool operator ==(Object other) =>
      other is ReviewLive &&
      other.rate.indexPrice == rate.indexPrice &&
      other.rate.userPrice == rate.userPrice;

  @override
  int get hashCode => Object.hash(ReviewLive, rate.indexPrice, rate.userPrice);
}

/// The index price fell to or under the target: the order would execute at
/// once, so Confirm is not offered; Back goes to change it.
final class ReviewTargetAbove extends LimitReviewCheck {
  final LimitOrderRate rate;

  const ReviewTargetAbove(this.rate);

  @override
  bool operator ==(Object other) =>
      other is ReviewTargetAbove && other.rate.indexPrice == rate.indexPrice;

  @override
  int get hashCode => Object.hash(ReviewTargetAbove, rate.indexPrice);
}

final class ReviewCheckFailed extends LimitReviewCheck {
  final ReadProblem problem;

  const ReviewCheckFailed(this.problem);

  @override
  bool operator ==(Object other) =>
      other is ReviewCheckFailed && other.problem == problem;

  @override
  int get hashCode => Object.hash(ReviewCheckFailed, problem);
}

/// Reading the account. Its failure has a Retry.
final class LimitLoading extends LimitFlowState {
  final ExchangeSession session;

  /// [ContextLoading] or [ContextFailed].
  final ContextLoadState<LimitOrderContext> load;

  const LimitLoading(this.session, this.load);

  @override
  List<Object?> get _props => [session, load];
}

/// No fiat balance to buy with: the only ways on are funding or leaving.
final class LimitNoFundedBalance extends LimitFlowState {
  final LimitOpen open;

  const LimitNoFundedBalance(this.open);

  @override
  List<Object?> get _props => [open];
}

/// What a limit order is; Continue reads the rate of [market].
final class LimitIntro extends LimitFlowState {
  final LimitOpen open;
  final Market market;

  const LimitIntro(this.open, this.market);

  @override
  List<Object?> get _props => [open, market];
}

final class LimitTarget extends LimitFlowState {
  final LimitOpen open;
  final LimitTargetStep step;

  const LimitTarget(this.open, this.step);

  @override
  List<Object?> get _props => [open, step];
}

/// Where the bitcoin goes: an exchange default wallet, an app wallet or a
/// typed Lightning address.
final class LimitDestination extends LimitFlowState {
  final LimitOpen open;
  final PricedTarget target;
  final LimitPickState pick;

  const LimitDestination(this.open, this.target, this.pick);

  @override
  List<Object?> get _props => [open, target, pick];
}

final class LimitAmount extends LimitFlowState {
  final LimitOpen open;
  final PricedTarget target;
  final Destination destination;

  /// Never [AmountDone] or [AmountSessionRejected]: those leave the step.
  final AmountEntryState amount;

  const LimitAmount(this.open, this.target, this.destination, this.amount);

  AmountPolicy get policy => limitAmountPolicy(target, destination);

  @override
  List<Object?> get _props => [open, target, destination, amount];
}

final class LimitReview extends LimitFlowState {
  final LimitOpen open;
  final LimitOrderRequest request;
  final int attempt;
  final LimitReviewCheck check;

  const LimitReview(this.open, this.request, this.attempt, this.check);

  @override
  List<Object?> get _props => [open, request, attempt, check];
}

/// The create, the money-moving write. Back here never re-offers it while
/// its outcome may be unknown.
final class LimitCreating extends LimitFlowState {
  final LimitOpen open;
  final LimitOrderRequest request;
  final LimitOrderRate rate;

  /// Never [ConfirmConfirmed], [ConfirmSessionEnded] or [ConfirmLeft].
  final LimitConfirmState confirm;

  const LimitCreating(this.open, this.request, this.rate, this.confirm);

  @override
  List<Object?> get _props => [open, request, rate.indexPrice, confirm];
}

/// The exchange created the limit order. No way back into the flow.
final class LimitDone extends LimitFlowState {
  final LimitOpen open;
  final LimitOrder order;

  const LimitDone(this.open, this.order);

  @override
  List<Object?> get _props => [open, order.id];
}

/// The session the flow opened with ended. The only exit is Close.
final class LimitSessionEnded extends LimitFlowState {
  const LimitSessionEnded();

  @override
  List<Object?> get _props => const [];
}

/// The user left the flow; [created] when it created an order, and
/// [openDetails] when they asked to see it.
final class LimitClosed extends LimitFlowState {
  final LimitOrder? created;
  final bool openDetails;

  const LimitClosed({this.created, this.openDetails = false});

  @override
  List<Object?> get _props => [created?.id, openDetails];
}

@immutable
sealed class LimitFlowEvent {
  const LimitFlowEvent();
}

final class LimitContextLoaded extends LimitFlowEvent {
  final int attempt;
  final ExchangeRead<LimitOrderContext> read;

  const LimitContextLoaded(this.attempt, this.read);
}

/// Retry of the page's failed read or write.
final class LimitRetryPressed extends LimitFlowEvent {
  const LimitRetryPressed();
}

final class LimitContinuePressed extends LimitFlowEvent {
  const LimitContinuePressed();
}

/// App bar, system Back or a page the user removed.
final class LimitBackPressed extends LimitFlowEvent {
  const LimitBackPressed();
}

/// Close (done page, session ended, Back to Exchange).
final class LimitDonePressed extends LimitFlowEvent {
  const LimitDonePressed();
}

final class LimitViewOrderPressed extends LimitFlowEvent {
  const LimitViewOrderPressed();
}

/// The signed-in session changed; null when signed out.
final class LimitSessionChanged extends LimitFlowEvent {
  final ExchangeSession? session;

  const LimitSessionChanged(this.session);
}

final class LimitCurrencyChosen extends LimitFlowEvent {
  final Market market;

  const LimitCurrencyChosen(this.market);
}

final class LimitPriceTyped extends LimitFlowEvent {
  final double price;

  const LimitPriceTyped(this.price);
}

final class LimitDiscountChanged extends LimitFlowEvent {
  final double discount;

  const LimitDiscountChanged(this.discount);
}

/// The target step's rate read of [attempt] for [market] answered [read].
final class LimitTargetRateArrived extends LimitFlowEvent {
  final Market market;
  final int attempt;
  final ExchangeRead<LimitOrderRate> read;

  const LimitTargetRateArrived(this.market, this.attempt, this.read);
}

final class LimitDestinationChanged extends LimitFlowEvent {
  final LimitPickEvent event;

  const LimitDestinationChanged(this.event);
}

final class LimitAmountChanged extends LimitFlowEvent {
  final AmountEntryEvent event;

  const LimitAmountChanged(this.event);
}

/// Back from the KYC web view the amount's detour opened.
final class LimitKycReturned extends LimitFlowEvent {
  const LimitKycReturned();
}

/// The account read again after the KYC detour.
final class LimitDetourLoaded extends LimitFlowEvent {
  final ExchangeRead<LimitOrderContext> read;

  const LimitDetourLoaded(this.read);
}

/// The review's rate read of [attempt] answered [read].
final class LimitReviewRateArrived extends LimitFlowEvent {
  final int attempt;
  final ExchangeRead<LimitOrderRate> read;

  const LimitReviewRateArrived(this.attempt, this.read);
}

final class LimitConfirmPressed extends LimitFlowEvent {
  const LimitConfirmPressed();
}

final class LimitConfirmChanged extends LimitFlowEvent {
  final LimitConfirmEvent event;

  const LimitConfirmChanged(this.event);
}

@immutable
sealed class LimitFlowEffect {
  const LimitFlowEffect();
}

final class LimitLoadContext extends LimitFlowEffect {
  final int attempt;

  const LimitLoadContext(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is LimitLoadContext && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(LimitLoadContext, attempt);
}

/// Read the rate of [market]; answer [LimitTargetRateArrived] for [attempt].
final class LimitFetchTargetRate extends LimitFlowEffect {
  final Market market;
  final int attempt;

  const LimitFetchTargetRate(this.market, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is LimitFetchTargetRate &&
      other.market == market &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(LimitFetchTargetRate, market, attempt);
}

final class LimitDestinationEffect extends LimitFlowEffect {
  final PickEffect<DestinationOption> effect;

  const LimitDestinationEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is LimitDestinationEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(LimitDestinationEffect, effect);
}

/// Read the account again after the KYC detour; answer [LimitDetourLoaded].
final class LimitReloadForDetour extends LimitFlowEffect {
  const LimitReloadForDetour();

  @override
  bool operator ==(Object other) => other is LimitReloadForDetour;

  @override
  int get hashCode => (LimitReloadForDetour).hashCode;
}

/// Read the rate of [market]; answer [LimitReviewRateArrived] for [attempt].
final class LimitFetchReviewRate extends LimitFlowEffect {
  final Market market;
  final int attempt;

  const LimitFetchReviewRate(this.market, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is LimitFetchReviewRate &&
      other.market == market &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(LimitFetchReviewRate, market, attempt);
}

final class LimitConfirmEffect extends LimitFlowEffect {
  final ServerConfirmEffect<LimitOrderRequest> effect;

  const LimitConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is LimitConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(LimitConfirmEffect, effect);
}

typedef LimitFlowNext = StepNext<LimitFlowState, LimitFlowEffect>;

const _ended = LimitFlowNext(LimitSessionEnded());
const _closed = LimitFlowNext(LimitClosed());

/// The flow for [session]; without a signed-in session it has ended.
LimitFlowNext limitFlowStart(ExchangeSession? session) => switch (session) {
  final session? => LimitFlowNext(
    LimitLoading(session, const ContextLoading(1)),
    const [LimitLoadContext(1)],
  ),
  null => _ended,
};

LimitFlowNext transitionLimitFlow(LimitFlowState state, LimitFlowEvent event) {
  if (event case LimitSessionChanged(:final session)) {
    final current = _sessionOf(state);
    return current != null && current != session
        ? _ended
        : LimitFlowNext.stay(state);
  }
  return switch (state) {
    LimitLoading() => _loading(state, event),
    LimitNoFundedBalance() => _noBalance(state, event),
    LimitIntro() => _intro(state, event),
    LimitTarget() => _target(state, event),
    LimitDestination() => _destination(state, event),
    LimitAmount() => _amount(state, event),
    LimitReview() => _review(state, event),
    LimitCreating() => _creating(state, event),
    LimitDone() => _done(state, event),
    LimitSessionEnded() => _sessionEnded(state, event),
    LimitClosed() => LimitFlowNext.stay(state),
  };
}

ExchangeSession? _sessionOf(LimitFlowState state) => switch (state) {
  LimitLoading(:final session) => session,
  LimitNoFundedBalance(:final open) ||
  LimitIntro(:final open) ||
  LimitTarget(:final open) ||
  LimitDestination(:final open) ||
  LimitAmount(:final open) ||
  LimitReview(:final open) ||
  LimitCreating(:final open) ||
  LimitDone(:final open) => open.session,
  LimitSessionEnded() || LimitClosed() => null,
};

/// A step's answer [next] to the flow: a stay of the step is a stay of the
/// flow (same instance, no effects).
LimitFlowNext _stepped<S, F>(
  LimitFlowState flow,
  StepNext<S, F> next,
  S current,
  LimitFlowNext Function(StepNext<S, F> next) map,
) => identical(next.state, current) && next.effects.isEmpty
    ? LimitFlowNext.stay(flow)
    : map(next);

LimitFlowNext _loading(LimitLoading state, LimitFlowEvent event) {
  final ContextLoadEvent<LimitOrderContext> loadEvent;
  switch (event) {
    case LimitContextLoaded(:final attempt, :final read):
      loadEvent = ContextLoaded(attempt, read);
    case LimitRetryPressed():
      loadEvent = const ContextRetryPressed();
    case LimitBackPressed() || LimitDonePressed():
      return _closed;
    case LimitContinuePressed() ||
        LimitViewOrderPressed() ||
        LimitSessionChanged() ||
        LimitCurrencyChosen() ||
        LimitPriceTyped() ||
        LimitDiscountChanged() ||
        LimitTargetRateArrived() ||
        LimitDestinationChanged() ||
        LimitAmountChanged() ||
        LimitKycReturned() ||
        LimitDetourLoaded() ||
        LimitReviewRateArrived() ||
        LimitConfirmPressed() ||
        LimitConfirmChanged():
      return LimitFlowNext.stay(state);
  }
  final next = transitionContextLoad(state.load, loadEvent);
  if (identical(next.state, state.load)) return LimitFlowNext.stay(state);
  return switch (next.state) {
    ContextReady(:final context) => _opened(LimitOpen(state.session, context)),
    ContextSessionRejected() => _ended,
    ContextLoading() || ContextFailed() => LimitFlowNext(
      LimitLoading(state.session, next.state),
      [
        for (final effect in next.effects)
          switch (effect) {
            ContextFetch(:final attempt) => LimitLoadContext(attempt),
          },
      ],
    ),
  };
}

LimitFlowNext _opened(LimitOpen open) => switch (open.context.preferredMarket) {
  final market? => LimitFlowNext(LimitIntro(open, market)),
  null => LimitFlowNext(LimitNoFundedBalance(open)),
};

LimitFlowNext _noBalance(LimitNoFundedBalance state, LimitFlowEvent event) =>
    switch (event) {
      LimitBackPressed() || LimitDonePressed() => _closed,
      LimitContextLoaded() ||
      LimitRetryPressed() ||
      LimitContinuePressed() ||
      LimitViewOrderPressed() ||
      LimitSessionChanged() ||
      LimitCurrencyChosen() ||
      LimitPriceTyped() ||
      LimitDiscountChanged() ||
      LimitTargetRateArrived() ||
      LimitDestinationChanged() ||
      LimitAmountChanged() ||
      LimitKycReturned() ||
      LimitDetourLoaded() ||
      LimitReviewRateArrived() ||
      LimitConfirmPressed() ||
      LimitConfirmChanged() => LimitFlowNext.stay(state),
    };

LimitFlowNext _loadTarget(
  LimitOpen open,
  Market market,
  int attempt, {
  PricedTarget? kept,
}) => LimitFlowNext(
  LimitTarget(open, TargetLoading(market, attempt, kept: kept)),
  [LimitFetchTargetRate(market, attempt)],
);

LimitFlowNext _intro(LimitIntro state, LimitFlowEvent event) => switch (event) {
  LimitContinuePressed() => _loadTarget(state.open, state.market, 1),
  LimitBackPressed() => _closed,
  LimitContextLoaded() ||
  LimitRetryPressed() ||
  LimitDonePressed() ||
  LimitViewOrderPressed() ||
  LimitSessionChanged() ||
  LimitCurrencyChosen() ||
  LimitPriceTyped() ||
  LimitDiscountChanged() ||
  LimitTargetRateArrived() ||
  LimitDestinationChanged() ||
  LimitAmountChanged() ||
  LimitKycReturned() ||
  LimitDetourLoaded() ||
  LimitReviewRateArrived() ||
  LimitConfirmPressed() ||
  LimitConfirmChanged() => LimitFlowNext.stay(state),
};

LimitFlowNext _target(LimitTarget state, LimitFlowEvent event) {
  final open = state.open;
  final step = state.step;
  LimitFlowNext ready(PricedTarget target, {ReadProblem? problem}) =>
      LimitFlowNext(
        LimitTarget(
          open,
          TargetReady(target, step.attempt, switchProblem: problem),
        ),
      );
  switch (event) {
    case LimitTargetRateArrived(:final market, :final attempt, :final read):
      final TargetLoading loading;
      switch (step) {
        case final TargetLoading awaited
            when awaited.market == market && awaited.attempt == attempt:
          loading = awaited;
        case TargetLoading() || TargetFailed() || TargetReady():
          return LimitFlowNext.stay(state);
      }
      final kept = loading.kept;
      return switch (read) {
        ReadGot(:final value) => ready(PricedTarget.at(market, value)),
        ReadSessionRejected() => _ended,
        ReadMissing() || ReadUnreachable() || ReadMalformed() => switch (kept) {
          final kept? => ready(kept, problem: ReadProblem.of(read)),
          null => LimitFlowNext(
            LimitTarget(
              open,
              TargetFailed(market, attempt, ReadProblem.of(read)!),
            ),
          ),
        },
      };
    case LimitCurrencyChosen(:final market):
      if (!open.context.fundedMarkets.contains(market)) {
        return LimitFlowNext.stay(state);
      }
      return switch (step) {
        TargetReady(:final target) when target.market == market =>
          LimitFlowNext.stay(state),
        TargetReady(:final target) => _loadTarget(
          open,
          market,
          step.attempt + 1,
          kept: target,
        ),
        TargetFailed() => _loadTarget(open, market, step.attempt + 1),
        TargetLoading() => LimitFlowNext.stay(state),
      };
    case LimitPriceTyped(:final price):
      return switch (step) {
        TargetReady(:final target) when price > 0 && price.isFinite => ready(
          target.withPrice(price),
        ),
        TargetReady() ||
        TargetLoading() ||
        TargetFailed() => LimitFlowNext.stay(state),
      };
    case LimitDiscountChanged(:final discount):
      return switch (step) {
        TargetReady(:final target) when discount.isFinite => ready(
          target.withDiscount(discount),
        ),
        TargetReady() ||
        TargetLoading() ||
        TargetFailed() => LimitFlowNext.stay(state),
      };
    case LimitRetryPressed():
      return switch (step) {
        TargetFailed(:final market, :final attempt) => _loadTarget(
          open,
          market,
          attempt + 1,
        ),
        TargetReady() || TargetLoading() => LimitFlowNext.stay(state),
      };
    case LimitContinuePressed():
      return switch (step) {
        TargetReady(:final target) => LimitFlowNext(
          LimitDestination(
            open,
            target,
            pickStart<DestinationOption, Destination>(
              open.context.destinationOptions,
            ).state,
          ),
        ),
        TargetLoading() || TargetFailed() => LimitFlowNext.stay(state),
      };
    case LimitBackPressed():
      return LimitFlowNext(
        LimitIntro(open, switch (step) {
          TargetLoading(:final market) || TargetFailed(:final market) => market,
          TargetReady(:final target) => target.market,
        }),
      );
    case LimitContextLoaded() ||
        LimitDonePressed() ||
        LimitViewOrderPressed() ||
        LimitSessionChanged() ||
        LimitDestinationChanged() ||
        LimitAmountChanged() ||
        LimitKycReturned() ||
        LimitDetourLoaded() ||
        LimitReviewRateArrived() ||
        LimitConfirmPressed() ||
        LimitConfirmChanged():
      return LimitFlowNext.stay(state);
  }
}

/// The pick's answer to [event]. A chosen destination is changed by a new
/// pick or a typed address: the pick starts over from its options first.
LimitPickNext _pick(LimitPickState pick, LimitPickEvent event) {
  final from = switch (pick) {
    PickChosen(:final options) when event is PickChose || event is PickTyped =>
      PickChoosing<DestinationOption, Destination>(options),
    PickChosen() ||
    PickChoosing() ||
    PickResolving() ||
    PickValidating() => pick,
  };
  final next = transitionPick(_destinationPolicy, from, event);
  return identical(next.state, from) && !identical(from, pick)
      ? LimitPickNext(from)
      : next;
}

typedef LimitPickNext = StepNext<LimitPickState, PickEffect<DestinationOption>>;

LimitFlowNext _destination(LimitDestination state, LimitFlowEvent event) {
  switch (event) {
    case LimitDestinationChanged(:final event):
      return _stepped(
        state,
        _pick(state.pick, event),
        state.pick,
        (next) => LimitFlowNext(
          LimitDestination(state.open, state.target, next.state),
          [for (final effect in next.effects) LimitDestinationEffect(effect)],
        ),
      );
    case LimitContinuePressed():
      return switch (state.pick) {
        PickChosen(:final value) => _amountStart(
          state.open,
          state.target,
          value,
        ),
        PickChoosing() ||
        PickResolving() ||
        PickValidating() => LimitFlowNext.stay(state),
      };
    case LimitBackPressed():
      return LimitFlowNext(
        LimitTarget(state.open, TargetReady(state.target, 1)),
      );
    case LimitContextLoaded() ||
        LimitRetryPressed() ||
        LimitDonePressed() ||
        LimitViewOrderPressed() ||
        LimitSessionChanged() ||
        LimitCurrencyChosen() ||
        LimitPriceTyped() ||
        LimitDiscountChanged() ||
        LimitTargetRateArrived() ||
        LimitAmountChanged() ||
        LimitKycReturned() ||
        LimitDetourLoaded() ||
        LimitReviewRateArrived() ||
        LimitConfirmPressed() ||
        LimitConfirmChanged():
      return LimitFlowNext.stay(state);
  }
}

/// The amount is checked at the target price: the estimated bitcoin is what
/// the order buys when it executes. That rate is known, so the step's rate
/// read is answered here, without a call.
LimitFlowNext _amountStart(
  LimitOpen open,
  PricedTarget target,
  Destination destination,
) => _amountNext(
  open,
  target,
  destination,
  amountEntryStart(
    limitAmountPolicy(target, destination),
    open.context.amountContext,
    preferred: target.market,
  ),
);

LimitFlowNext _amountNext(
  LimitOpen open,
  PricedTarget target,
  Destination destination,
  AmountEntryNext next,
) {
  for (final effect in next.effects) {
    switch (effect) {
      case AmountFetchRate(:final market):
        return _amountNext(
          open,
          target,
          destination,
          transitionAmountEntry(
            limitAmountPolicy(target, destination),
            next.state,
            AmountRateArrived(market, ReadGot(target.limitPrice)),
          ),
        );
      // The detour page opens KYC; its return is LimitKycReturned. Over the
      // balance is a warning, so funding is never offered.
      case AmountOpenKyc() || AmountOpenFunding():
        break;
    }
  }
  return switch (next.state) {
    AmountDone(:final amount) => _reviewStart(
      open,
      LimitOrderRequest(target, destination, amount),
      1,
    ),
    AmountSessionRejected() => _ended,
    AmountNoMarket() ||
    AmountEditing() ||
    AmountKycDetour() ||
    AmountFundingDetour() => LimitFlowNext(
      LimitAmount(open, target, destination, next.state),
    ),
  };
}

LimitFlowNext _amount(LimitAmount state, LimitFlowEvent event) {
  switch (event) {
    case LimitAmountChanged(:final event):
      return _stepped(
        state,
        transitionAmountEntry(state.policy, state.amount, event),
        state.amount,
        (next) =>
            _amountNext(state.open, state.target, state.destination, next),
      );
    case LimitContinuePressed():
      return _stepped(
        state,
        transitionAmountEntry(
          state.policy,
          state.amount,
          const AmountContinuePressed(),
        ),
        state.amount,
        (next) =>
            _amountNext(state.open, state.target, state.destination, next),
      );
    case LimitKycReturned():
      return switch (state.amount) {
        AmountKycDetour() => LimitFlowNext(state, const [
          LimitReloadForDetour(),
        ]),
        AmountNoMarket() ||
        AmountEditing() ||
        AmountFundingDetour() ||
        AmountDone() ||
        AmountSessionRejected() => LimitFlowNext.stay(state),
      };
    case LimitDetourLoaded(:final read):
      return switch (state.amount) {
        AmountKycDetour() => switch (read) {
          ReadGot(value: final context) => _amountNext(
            LimitOpen(state.open.session, context),
            state.target,
            state.destination,
            transitionAmountEntry(
              state.policy,
              state.amount,
              AmountDetourReturned(context.amountContext),
            ),
          ),
          ReadSessionRejected() => _ended,
          // The detour page stays; returning again reads again.
          ReadMissing() ||
          ReadUnreachable() ||
          ReadMalformed() => LimitFlowNext.stay(state),
        },
        AmountNoMarket() ||
        AmountEditing() ||
        AmountFundingDetour() ||
        AmountDone() ||
        AmountSessionRejected() => LimitFlowNext.stay(state),
      };
    case LimitBackPressed():
      return LimitFlowNext(
        LimitDestination(
          state.open,
          state.target,
          PickChosen<DestinationOption, Destination>(
            state.open.context.destinationOptions,
            state.destination,
          ),
        ),
      );
    case LimitContextLoaded() ||
        LimitRetryPressed() ||
        LimitDonePressed() ||
        LimitViewOrderPressed() ||
        LimitSessionChanged() ||
        LimitCurrencyChosen() ||
        LimitPriceTyped() ||
        LimitDiscountChanged() ||
        LimitTargetRateArrived() ||
        LimitDestinationChanged() ||
        LimitReviewRateArrived() ||
        LimitConfirmPressed() ||
        LimitConfirmChanged():
      return LimitFlowNext.stay(state);
  }
}

LimitFlowNext _reviewStart(
  LimitOpen open,
  LimitOrderRequest request,
  int attempt,
) => LimitFlowNext(
  LimitReview(open, request, attempt, const ReviewChecking()),
  [LimitFetchReviewRate(request.target.market, attempt)],
);

/// Back to the amount with the entered draft kept.
LimitFlowNext _editAmount(LimitOpen open, LimitOrderRequest request) =>
    _amountNext(
      open,
      request.target,
      request.destination,
      transitionAmountEntry(
        limitAmountPolicy(request.target, request.destination),
        AmountDone(request.amount, open.context.amountContext),
        const AmountEditRequested(),
      ),
    );

LimitFlowNext _review(LimitReview state, LimitFlowEvent event) {
  switch (event) {
    case LimitReviewRateArrived(:final attempt, :final read):
      if (attempt != state.attempt) return LimitFlowNext.stay(state);
      switch (state.check) {
        case ReviewChecking():
          break;
        case ReviewLive() || ReviewTargetAbove() || ReviewCheckFailed():
          return LimitFlowNext.stay(state);
      }
      LimitFlowNext checked(LimitReviewCheck check) => LimitFlowNext(
        LimitReview(state.open, state.request, state.attempt, check),
      );
      return switch (read) {
        ReadGot(:final value)
            when state.request.target.limitPrice < value.indexPrice =>
          checked(ReviewLive(value)),
        ReadGot(:final value) => checked(ReviewTargetAbove(value)),
        ReadMissing() ||
        ReadUnreachable() ||
        ReadMalformed() => checked(ReviewCheckFailed(ReadProblem.of(read)!)),
        ReadSessionRejected() => _ended,
      };
    case LimitRetryPressed():
      return switch (state.check) {
        ReviewCheckFailed() => _reviewStart(
          state.open,
          state.request,
          state.attempt + 1,
        ),
        ReviewChecking() ||
        ReviewLive() ||
        ReviewTargetAbove() => LimitFlowNext.stay(state),
      };
    case LimitConfirmPressed():
      return switch (state.check) {
        ReviewLive(:final rate) => _creatingNext(
          state.open,
          state.request,
          rate,
          serverConfirmStart<LimitOrderRequest, LimitOrder>(
            state.request,
            openEntry: openEntryFor(
              limitOrderCreatePolicy,
              state.request,
              state.open.context.openEntries,
            ),
          ),
        ),
        ReviewChecking() ||
        ReviewTargetAbove() ||
        ReviewCheckFailed() => LimitFlowNext.stay(state),
      };
    case LimitBackPressed():
      return _editAmount(state.open, state.request);
    case LimitContextLoaded() ||
        LimitContinuePressed() ||
        LimitDonePressed() ||
        LimitViewOrderPressed() ||
        LimitSessionChanged() ||
        LimitCurrencyChosen() ||
        LimitPriceTyped() ||
        LimitDiscountChanged() ||
        LimitTargetRateArrived() ||
        LimitDestinationChanged() ||
        LimitAmountChanged() ||
        LimitKycReturned() ||
        LimitDetourLoaded() ||
        LimitConfirmChanged():
      return LimitFlowNext.stay(state);
  }
}

LimitFlowNext _creatingNext(
  LimitOpen open,
  LimitOrderRequest request,
  LimitOrderRate rate,
  ServerConfirmNext<LimitOrderRequest, LimitOrder> next,
) => switch (next.state) {
  ConfirmConfirmed(:final confirmed) => LimitFlowNext(
    LimitDone(open, confirmed),
  ),
  ConfirmSessionEnded() => _ended,
  // Leaving a failed, refused or unverified create ends the flow: going back
  // to the review could send a second create while the first may exist.
  ConfirmLeft() => _closed,
  ConfirmConfirming() ||
  ConfirmWriteRefused() ||
  ConfirmFailed() ||
  ConfirmVerifying() ||
  ConfirmUnverified() => LimitFlowNext(
    LimitCreating(open, request, rate, next.state),
    [for (final effect in next.effects) LimitConfirmEffect(effect)],
  ),
};

LimitFlowNext _creating(LimitCreating state, LimitFlowEvent event) {
  final LimitConfirmEvent stepEvent;
  switch (event) {
    case LimitConfirmChanged(:final event):
      stepEvent = event;
    case LimitConfirmPressed():
      stepEvent = const ConfirmCommitPressed();
    case LimitRetryPressed():
      stepEvent = const ConfirmRetryPressed();
    case LimitBackPressed():
      stepEvent = const ConfirmBackPressed();
    case LimitContextLoaded() ||
        LimitContinuePressed() ||
        LimitDonePressed() ||
        LimitViewOrderPressed() ||
        LimitSessionChanged() ||
        LimitCurrencyChosen() ||
        LimitPriceTyped() ||
        LimitDiscountChanged() ||
        LimitTargetRateArrived() ||
        LimitDestinationChanged() ||
        LimitAmountChanged() ||
        LimitKycReturned() ||
        LimitDetourLoaded() ||
        LimitReviewRateArrived():
      return LimitFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionServerConfirm(limitOrderCreatePolicy, state.confirm, stepEvent),
    state.confirm,
    (next) => _creatingNext(state.open, state.request, state.rate, next),
  );
}

LimitFlowNext _done(LimitDone state, LimitFlowEvent event) => switch (event) {
  LimitDonePressed() ||
  LimitBackPressed() => LimitFlowNext(LimitClosed(created: state.order)),
  LimitViewOrderPressed() => LimitFlowNext(
    LimitClosed(created: state.order, openDetails: true),
  ),
  LimitContextLoaded() ||
  LimitRetryPressed() ||
  LimitContinuePressed() ||
  LimitSessionChanged() ||
  LimitCurrencyChosen() ||
  LimitPriceTyped() ||
  LimitDiscountChanged() ||
  LimitTargetRateArrived() ||
  LimitDestinationChanged() ||
  LimitAmountChanged() ||
  LimitKycReturned() ||
  LimitDetourLoaded() ||
  LimitReviewRateArrived() ||
  LimitConfirmPressed() ||
  LimitConfirmChanged() => LimitFlowNext.stay(state),
};

LimitFlowNext _sessionEnded(LimitSessionEnded state, LimitFlowEvent event) =>
    switch (event) {
      LimitDonePressed() || LimitBackPressed() => _closed,
      LimitContextLoaded() ||
      LimitRetryPressed() ||
      LimitContinuePressed() ||
      LimitViewOrderPressed() ||
      LimitSessionChanged() ||
      LimitCurrencyChosen() ||
      LimitPriceTyped() ||
      LimitDiscountChanged() ||
      LimitTargetRateArrived() ||
      LimitDestinationChanged() ||
      LimitAmountChanged() ||
      LimitKycReturned() ||
      LimitDetourLoaded() ||
      LimitReviewRateArrived() ||
      LimitConfirmPressed() ||
      LimitConfirmChanged() => LimitFlowNext.stay(state),
    };
