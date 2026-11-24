import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

/// The sell flow (composition §5, Sell column): session → account load →
/// amount (any market, fiat or BTC) → payin source → payout (the fiat
/// balance, or an own recipient on the market's rails with its
/// requirements) → order create and quote → payin → done. Every state holds
/// the session it opened with and only the data valid in it.
@immutable
sealed class SellFlowState {
  const SellFlowState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is SellFlowState &&
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

/// The account and the open journal entries: an order with an open payin
/// entry starts its payin in Verifying, never offering the send again.
@immutable
final class SellContext {
  final UserSummary summary;
  final List<UnknownWrite> openEntries;

  const SellContext(this.summary, this.openEntries);

  AmountContext get amountContext =>
      AmountContext(kycGroups: summary.kycGroups, balances: const {});

  Market? get preferredMarket => switch (summary.currency) {
    final code? => switch (ExchangeCatalog.parse(code)) {
      KnownCurrency(:final market) => market,
      UnknownCurrency() => null,
    },
    null => null,
  };

  @override
  bool operator ==(Object other) =>
      other is SellContext &&
      other.summary == summary &&
      identical(other.openEntries, openEntries);

  @override
  int get hashCode => Object.hash(summary, openEntries.length);
}

@immutable
final class SellOpen {
  final ExchangeSession session;
  final SellContext context;

  const SellOpen(this.session, this.context);

  @override
  bool operator ==(Object other) =>
      other is SellOpen && other.session == session && other.context == context;

  @override
  int get hashCode => Object.hash(session, context);
}

/// Where the sale's fiat goes.
@immutable
sealed class SellPayout {
  const SellPayout();
}

/// The account's fiat balance in the amount's currency.
final class SellToBalance extends SellPayout {
  const SellToBalance();

  @override
  bool operator ==(Object other) => other is SellToBalance;

  @override
  int get hashCode => (SellToBalance).hashCode;
}

/// An own recipient on the market's rails, its requirements met: the order
/// is a payment order to it, with its payout params (Interac answer
/// included when the rail asks for one).
final class SellToRecipient extends SellPayout {
  final ReadyRecipient recipient;

  const SellToRecipient(this.recipient);

  @override
  bool operator ==(Object other) =>
      other is SellToRecipient && other.recipient == recipient;

  @override
  int get hashCode => Object.hash(SellToRecipient, recipient);
}

/// What the payout page offers: the balance, or a recipient (then picked).
enum SellPayoutChoice { balance, recipient }

/// The order create: the entered amount, paid in from [source], to [payout].
@immutable
final class SellRequest {
  final EnteredAmount amount;
  final PayinSource source;
  final SellPayout payout;

  const SellRequest(this.amount, this.source, this.payout);

  /// The amount as the user entered it.
  OrderAmount get orderAmount => switch (amount.enteredIn) {
    AmountUnit.fiat => FiatAmount(amount.fiat),
    AmountUnit.bitcoin => BitcoinAmount(amount.sats / 100000000),
  };

  OrderCreateJournalRequest get journal => switch (payout) {
    SellToBalance() => OrderCreateJournalRequest(
      type: OrderType.sell,
      amount: orderAmount,
      currency: amount.market.currency,
    ),
    SellToRecipient(:final recipient) => OrderCreateJournalRequest(
      type: OrderType.fiatPayment,
      amount: orderAmount,
      currency: amount.market.currency,
      recipientId: recipient.orderParams.recipientId,
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is SellRequest &&
      other.amount == amount &&
      other.source == source &&
      other.payout == payout;

  @override
  int get hashCode => Object.hash(amount, source, payout);
}

/// Sell's amount policy: any market, fiat or BTC, the KYC level checked
/// against the market's limits; the bitcoin comes from a wallet, so there
/// is no fiat balance to check.
const sellAmountPolicy = AmountPolicy(
  currencySource: CurrencyPicker(ExchangeCatalog.markets),
  allowBitcoinUnit: true,
  checkBalance: false,
  onShortfall: BalanceShortfall.block,
  checkKyc: true,
  withDescription: false,
);

String _orderId(Order order) => order.orderId;

/// A sell or payment order holds a price lock until its deadline.
const sellOrderPolicy = OrderPolicy<Order>(idOf: _orderId, locks: true);

const sellRequirementsPolicy = RequirementsPolicy();

/// The order watch after the payin: bounded, as every watch.
const sellPayinPolicy = PayinPolicy(
  maxPolls: 120,
  maxDuration: Duration(minutes: 10),
  maxUnreadable: 5,
);

/// The recipients a sale may pay: the user's own, on the market's rails.
RecipientFilter sellRecipientFilter(Market market) =>
    RecipientFilter(rails: market.payoutRails, owner: RecipientOwnership.own);

/// Whether [source] can pay in: an app wallet on a rail the app can spend
/// from, or any rail that can be paid from outside.
bool sellSourceAllowed(PayinSource source) => switch (source) {
  PayinFromAppWallet(:final rail) => rail.rail.canBeAppWallet,
  PayinFromExternal(:final rail) => rail.rail.canBeExternalPayin,
};

typedef SellOrderState = OrderStepState<SellRequest, Order>;
typedef SellOrderEvent = OrderStepEvent<SellRequest, Order>;
typedef SellPayinState = PayinState<PayinSpend>;
typedef SellPayinEvent = PayinEvent<PayinSpend>;

final class SellLoading extends SellFlowState {
  final ExchangeSession session;

  /// [ContextLoading] or [ContextFailed].
  final ContextLoadState<SellContext> load;

  const SellLoading(this.session, this.load);

  @override
  List<Object?> get _props => [session, load];
}

final class SellAmount extends SellFlowState {
  final SellOpen open;

  /// Never [AmountDone] or [AmountSessionRejected].
  final AmountEntryState amount;

  const SellAmount(this.open, this.amount);

  @override
  List<Object?> get _props => [open, amount];
}

/// Picking the wallet (or outside rail) that pays the bitcoin in.
final class SellSource extends SellFlowState {
  final SellOpen open;
  final EnteredAmount amount;

  const SellSource(this.open, this.amount);

  @override
  List<Object?> get _props => [open, amount];
}

/// The fiat balance or a recipient.
final class SellPayoutPick extends SellFlowState {
  final SellOpen open;
  final EnteredAmount amount;
  final PayinSource source;

  const SellPayoutPick(this.open, this.amount, this.source);

  @override
  List<Object?> get _props => [open, amount, source];
}

/// Picking one of the user's own recipients on the market's rails.
final class SellRecipient extends SellFlowState {
  final SellOpen open;
  final EnteredAmount amount;
  final PayinSource source;
  final Recipient? refused;

  const SellRecipient(this.open, this.amount, this.source, {this.refused});

  RecipientFilter get filter => sellRecipientFilter(amount.market);

  @override
  List<Object?> get _props => [open, amount, source, refused];
}

final class SellRequirements extends SellFlowState {
  final SellOpen open;
  final EnteredAmount amount;
  final PayinSource source;
  final RequirementsRunning requirements;

  const SellRequirements(
    this.open,
    this.amount,
    this.source,
    this.requirements,
  );

  @override
  List<Object?> get _props => [open, amount, source, requirements];
}

/// Creating the order and holding its quote; [OrderQuoted] is the review
/// with Confirm (live quote only).
final class SellOrdering extends SellFlowState {
  final SellOpen open;
  final SellRequest request;

  /// Never [OrderPlaced], [OrderCommitted], [OrderLeft] or
  /// [OrderSessionEnded].
  final SellOrderState order;

  const SellOrdering(this.open, this.request, this.order);

  @override
  List<Object?> get _props => [open, request, order];
}

/// Paying the committed order in.
final class SellPaying extends SellFlowState {
  final SellOpen open;
  final SellRequest request;
  final QuotedOrder<Order> quoted;

  /// Never [PayinCompleted], [PayinQuoteLapsed], [PayinLeft],
  /// [PayinLeftPending] or [PayinSessionEnded].
  final SellPayinState payin;

  const SellPaying(this.open, this.request, this.quoted, this.payin);

  @override
  List<Object?> get _props => [open, request, quoted, payin];
}

/// The exchange received the payin (under review included). Says "payment
/// received", not "order completed" (SELL-11).
final class SellDone extends SellFlowState {
  final SellOpen open;
  final Order order;
  final String? txid;

  const SellDone(this.open, this.order, this.txid);

  @override
  List<Object?> get _props => [open, order.orderId, txid];
}

final class SellSessionEnded extends SellFlowState {
  const SellSessionEnded();

  @override
  List<Object?> get _props => const [];
}

final class SellClosed extends SellFlowState {
  const SellClosed();

  @override
  List<Object?> get _props => const [];
}

@immutable
sealed class SellFlowEvent {
  const SellFlowEvent();
}

final class SellContextLoaded extends SellFlowEvent {
  final int attempt;
  final ExchangeRead<SellContext> read;

  const SellContextLoaded(this.attempt, this.read);
}

final class SellRetryPressed extends SellFlowEvent {
  const SellRetryPressed();
}

final class SellAmountChanged extends SellFlowEvent {
  final AmountEntryEvent event;

  const SellAmountChanged(this.event);
}

/// Back from the KYC detour; the account is read again.
final class SellKycReturned extends SellFlowEvent {
  const SellKycReturned();
}

final class SellDetourLoaded extends SellFlowEvent {
  final ExchangeRead<SellContext> read;

  const SellDetourLoaded(this.read);
}

final class SellSourcePicked extends SellFlowEvent {
  final PayinSource source;

  const SellSourcePicked(this.source);
}

final class SellPayoutPicked extends SellFlowEvent {
  final SellPayoutChoice choice;

  const SellPayoutPicked(this.choice);
}

final class SellRecipientPicked extends SellFlowEvent {
  final Recipient recipient;

  const SellRecipientPicked(this.recipient);
}

final class SellRequirementsChanged extends SellFlowEvent {
  final RequirementsEvent event;

  const SellRequirementsChanged(this.event);
}

final class SellOrderChanged extends SellFlowEvent {
  final SellOrderEvent event;

  const SellOrderChanged(this.event);
}

/// Confirm on a live quote, [at] the time pressed (the payin checks the
/// order's deadline against it).
final class SellConfirmPressed extends SellFlowEvent {
  final DateTime at;

  const SellConfirmPressed(this.at);
}

final class SellPayinChanged extends SellFlowEvent {
  final SellPayinEvent event;

  const SellPayinChanged(this.event);
}

final class SellBackPressed extends SellFlowEvent {
  const SellBackPressed();
}

final class SellDonePressed extends SellFlowEvent {
  const SellDonePressed();
}

final class SellVisibilityChanged extends SellFlowEvent {
  final bool visible;

  const SellVisibilityChanged({required this.visible});
}

final class SellSessionChanged extends SellFlowEvent {
  final ExchangeSession? session;

  const SellSessionChanged(this.session);
}

@immutable
sealed class SellFlowEffect {
  const SellFlowEffect();

  Object get _value;

  @override
  bool operator ==(Object other) =>
      other is SellFlowEffect &&
      other.runtimeType == runtimeType &&
      other._value == _value;

  @override
  int get hashCode => Object.hash(runtimeType, _value);

  @override
  String toString() => '$runtimeType($_value)';
}

final class SellLoadContext extends SellFlowEffect {
  final int attempt;

  const SellLoadContext(this.attempt);

  @override
  Object get _value => attempt;
}

/// Read the account again after the KYC detour.
final class SellReloadForDetour extends SellFlowEffect {
  const SellReloadForDetour();

  @override
  Object get _value => 0;
}

final class SellFetchRate extends SellFlowEffect {
  final Market market;

  const SellFetchRate(this.market);

  @override
  Object get _value => market;
}

final class SellRequirementsEffect extends SellFlowEffect {
  final RequirementsEffect effect;

  const SellRequirementsEffect(this.effect);

  @override
  Object get _value => effect;
}

final class SellOrderEffect extends SellFlowEffect {
  final OrderStepEffect<SellRequest> effect;

  const SellOrderEffect(this.effect);

  @override
  Object get _value => effect;
}

final class SellPayinEffect extends SellFlowEffect {
  final PayinEffect<PayinSpend> effect;

  const SellPayinEffect(this.effect);

  @override
  Object get _value => effect;
}

typedef SellFlowNext = StepNext<SellFlowState, SellFlowEffect>;

const _ended = SellFlowNext(SellSessionEnded());
const _closed = SellFlowNext(SellClosed());

SellFlowNext sellFlowStart(ExchangeSession? session) => switch (session) {
  final session? => SellFlowNext(
    SellLoading(session, const ContextLoading(1)),
    [const SellLoadContext(1)],
  ),
  null => _ended,
};

SellFlowNext transitionSellFlow(SellFlowState state, SellFlowEvent event) {
  if (event case SellSessionChanged(:final session)) {
    final current = _sessionOf(state);
    return current != null && current != session
        ? SellFlowNext(const SellSessionEnded(), _stopAll(state))
        : SellFlowNext.stay(state);
  }
  return switch (state) {
    SellLoading() => _loading(state, event),
    SellAmount() => _amount(state, event),
    SellSource() => _source(state, event),
    SellPayoutPick() => _payout(state, event),
    SellRecipient() => _recipient(state, event),
    SellRequirements() => _requirements(state, event),
    SellOrdering() => _ordering(state, event),
    SellPaying() => _paying(state, event),
    SellDone() => _terminal(state, event),
    SellSessionEnded() => _terminal(state, event),
    SellClosed() => SellFlowNext.stay(state),
  };
}

ExchangeSession? _sessionOf(SellFlowState state) => switch (state) {
  SellLoading(:final session) => session,
  SellAmount(:final open) ||
  SellSource(:final open) ||
  SellPayoutPick(:final open) ||
  SellRecipient(:final open) ||
  SellRequirements(:final open) ||
  SellOrdering(:final open) ||
  SellPaying(:final open) ||
  SellDone(:final open) => open.session,
  SellSessionEnded() || SellClosed() => null,
};

/// What a session change stops: the quote timers of a held order, the
/// payjoin watch and order watch of a payin, the requirement polls.
List<SellFlowEffect> _stopAll(SellFlowState state) => switch (state) {
  SellOrdering(order: OrderQuoted(:final quoted)) => [
    SellOrderEffect(OrderStopTimers(quoted.id)),
  ],
  SellPaying(:final quoted, :final payin) => [
    if (payin
        case PayinPayjoinNegotiating(:final sessionId) ||
            PayinPayjoinPaused(:final sessionId))
      SellPayinEffect(PayinStopPayjoin(sessionId)),
    SellPayinEffect(PayinWatchEffect(WatchStop(quoted.id))),
  ],
  // Requirement polls are bounded by their deadlines; their late answers
  // find no Requirements state and are dropped.
  SellLoading() ||
  SellRequirements() ||
  SellAmount() ||
  SellSource() ||
  SellPayoutPick() ||
  SellRecipient() ||
  SellOrdering() ||
  SellDone() ||
  SellSessionEnded() ||
  SellClosed() => const [],
};

/// A step's answer to the flow: a stay of the step is a stay of the flow.
SellFlowNext _stepped<S, F>(
  SellFlowState flow,
  StepNext<S, F> next,
  S current,
  SellFlowNext Function(StepNext<S, F> next) map,
) => identical(next.state, current) && next.effects.isEmpty
    ? SellFlowNext.stay(flow)
    : map(next);

SellFlowNext _loading(SellLoading state, SellFlowEvent event) {
  final ContextLoadEvent<SellContext> loadEvent;
  switch (event) {
    case SellContextLoaded(:final attempt, :final read):
      loadEvent = ContextLoaded(attempt, read);
    case SellRetryPressed():
      loadEvent = const ContextRetryPressed();
    case SellBackPressed() || SellDonePressed():
      return _closed;
    case SellAmountChanged() ||
        SellKycReturned() ||
        SellDetourLoaded() ||
        SellSourcePicked() ||
        SellPayoutPicked() ||
        SellRecipientPicked() ||
        SellRequirementsChanged() ||
        SellOrderChanged() ||
        SellConfirmPressed() ||
        SellPayinChanged() ||
        SellVisibilityChanged() ||
        SellSessionChanged():
      return SellFlowNext.stay(state);
  }
  final next = transitionContextLoad(state.load, loadEvent);
  if (identical(next.state, state.load)) return SellFlowNext.stay(state);
  return switch (next.state) {
    ContextReady(:final context) => _amountNext(
      SellOpen(state.session, context),
      amountEntryStart(
        sellAmountPolicy,
        context.amountContext,
        preferred: context.preferredMarket,
      ),
    ),
    ContextSessionRejected() => _ended,
    ContextLoading() || ContextFailed() => SellFlowNext(
      SellLoading(state.session, next.state),
      [
        for (final effect in next.effects)
          switch (effect) {
            ContextFetch(:final attempt) => SellLoadContext(attempt),
          },
      ],
    ),
  };
}

SellFlowNext _amountNext(SellOpen open, AmountEntryNext next) =>
    switch (next.state) {
      AmountDone(:final amount) => SellFlowNext(SellSource(open, amount)),
      AmountSessionRejected() => _ended,
      AmountNoMarket() ||
      AmountEditing() ||
      AmountKycDetour() ||
      AmountFundingDetour() => SellFlowNext(SellAmount(open, next.state), [
        for (final effect in next.effects)
          ...switch (effect) {
            AmountFetchRate(:final market) => [SellFetchRate(market)],
            // The detour page opens KYC; its return is SellKycReturned.
            // Sell offers no funding (no fiat balance is spent).
            AmountOpenKyc() || AmountOpenFunding() => const <SellFlowEffect>[],
          },
      ]),
    };

SellFlowNext _amount(SellAmount state, SellFlowEvent event) => switch (event) {
  SellAmountChanged(:final event) => _stepped(
    state,
    transitionAmountEntry(sellAmountPolicy, state.amount, event),
    state.amount,
    (next) => _amountNext(state.open, next),
  ),
  SellKycReturned() => switch (state.amount) {
    AmountKycDetour() => SellFlowNext(state, const [SellReloadForDetour()]),
    AmountNoMarket() ||
    AmountEditing() ||
    AmountFundingDetour() ||
    AmountDone() ||
    AmountSessionRejected() => SellFlowNext.stay(state),
  },
  SellDetourLoaded(:final read) => switch (state.amount) {
    AmountKycDetour() => switch (read) {
      ReadGot(value: final context) => _amountNext(
        SellOpen(state.open.session, context),
        transitionAmountEntry(
          sellAmountPolicy,
          state.amount,
          AmountDetourReturned(context.amountContext),
        ),
      ),
      ReadSessionRejected() => _ended,
      // The detour page stays; returning again reads again.
      ReadMissing() ||
      ReadUnreachable() ||
      ReadMalformed() => SellFlowNext.stay(state),
    },
    AmountNoMarket() ||
    AmountEditing() ||
    AmountFundingDetour() ||
    AmountDone() ||
    AmountSessionRejected() => SellFlowNext.stay(state),
  },
  SellBackPressed() => _closed,
  SellContextLoaded() ||
  SellRetryPressed() ||
  SellSourcePicked() ||
  SellPayoutPicked() ||
  SellRecipientPicked() ||
  SellRequirementsChanged() ||
  SellOrderChanged() ||
  SellConfirmPressed() ||
  SellPayinChanged() ||
  SellDonePressed() ||
  SellVisibilityChanged() ||
  SellSessionChanged() => SellFlowNext.stay(state),
};

/// Back to the amount with the entered draft kept.
SellFlowNext _editAmount(SellOpen open, EnteredAmount amount) => _amountNext(
  open,
  transitionAmountEntry(
    sellAmountPolicy,
    AmountDone(amount, open.context.amountContext),
    const AmountEditRequested(),
  ),
);

SellFlowNext _source(SellSource state, SellFlowEvent event) => switch (event) {
  SellSourcePicked(:final source) =>
    sellSourceAllowed(source)
        ? SellFlowNext(SellPayoutPick(state.open, state.amount, source))
        : SellFlowNext.stay(state),
  SellBackPressed() => _editAmount(state.open, state.amount),
  SellContextLoaded() ||
  SellRetryPressed() ||
  SellAmountChanged() ||
  SellKycReturned() ||
  SellDetourLoaded() ||
  SellPayoutPicked() ||
  SellRecipientPicked() ||
  SellRequirementsChanged() ||
  SellOrderChanged() ||
  SellConfirmPressed() ||
  SellPayinChanged() ||
  SellDonePressed() ||
  SellVisibilityChanged() ||
  SellSessionChanged() => SellFlowNext.stay(state),
};

SellFlowNext _payout(SellPayoutPick state, SellFlowEvent event) =>
    switch (event) {
      SellPayoutPicked(choice: SellPayoutChoice.balance) => _order(
        state.open,
        SellRequest(state.amount, state.source, const SellToBalance()),
        orderCreateStart<SellRequest, Order>(
          SellRequest(state.amount, state.source, const SellToBalance()),
        ),
      ),
      SellPayoutPicked(choice: SellPayoutChoice.recipient) => SellFlowNext(
        SellRecipient(state.open, state.amount, state.source),
      ),
      SellBackPressed() => SellFlowNext(SellSource(state.open, state.amount)),
      SellContextLoaded() ||
      SellRetryPressed() ||
      SellAmountChanged() ||
      SellKycReturned() ||
      SellDetourLoaded() ||
      SellSourcePicked() ||
      SellRecipientPicked() ||
      SellRequirementsChanged() ||
      SellOrderChanged() ||
      SellConfirmPressed() ||
      SellPayinChanged() ||
      SellDonePressed() ||
      SellVisibilityChanged() ||
      SellSessionChanged() => SellFlowNext.stay(state),
    };

SellFlowNext _recipient(SellRecipient state, SellFlowEvent event) =>
    switch (event) {
      SellRecipientPicked(:final recipient) => switch (state.filter.choose(
        recipient,
      )) {
        final chosen? => _requirementsNext(
          state.open,
          state.amount,
          state.source,
          requirementsStart(sellRequirementsPolicy, chosen, PayoutPurpose.sell),
        ),
        null => SellFlowNext(
          SellRecipient(
            state.open,
            state.amount,
            state.source,
            refused: recipient,
          ),
        ),
      },
      SellBackPressed() => SellFlowNext(
        SellPayoutPick(state.open, state.amount, state.source),
      ),
      SellContextLoaded() ||
      SellRetryPressed() ||
      SellAmountChanged() ||
      SellKycReturned() ||
      SellDetourLoaded() ||
      SellSourcePicked() ||
      SellPayoutPicked() ||
      SellRequirementsChanged() ||
      SellOrderChanged() ||
      SellConfirmPressed() ||
      SellPayinChanged() ||
      SellDonePressed() ||
      SellVisibilityChanged() ||
      SellSessionChanged() => SellFlowNext.stay(state),
    };

SellFlowNext _requirementsNext(
  SellOpen open,
  EnteredAmount amount,
  PayinSource source,
  RequirementsNext next,
) => switch (next.state) {
  RequirementsReady(:final ready) => _order(
    open,
    SellRequest(amount, source, SellToRecipient(ready)),
    orderCreateStart<SellRequest, Order>(
      SellRequest(amount, source, SellToRecipient(ready)),
    ),
  ),
  RequirementsCancelled() => SellFlowNext(SellRecipient(open, amount, source)),
  RequirementsSessionEnded() => _ended,
  final RequirementsRunning running => SellFlowNext(
    SellRequirements(open, amount, source, running),
    [for (final effect in next.effects) SellRequirementsEffect(effect)],
  ),
};

SellFlowNext _requirements(SellRequirements state, SellFlowEvent event) {
  final RequirementsEvent stepEvent;
  switch (event) {
    case SellRequirementsChanged(:final event):
      stepEvent = event;
    case SellBackPressed():
      stepEvent = const RequirementsCancelPressed();
    case SellVisibilityChanged(:final visible):
      final visibility = requirementsVisibility(state.requirements, visible);
      if (visibility == null) return SellFlowNext.stay(state);
      stepEvent = visibility;
    case SellContextLoaded() ||
        SellRetryPressed() ||
        SellAmountChanged() ||
        SellKycReturned() ||
        SellDetourLoaded() ||
        SellSourcePicked() ||
        SellPayoutPicked() ||
        SellRecipientPicked() ||
        SellOrderChanged() ||
        SellConfirmPressed() ||
        SellPayinChanged() ||
        SellDonePressed() ||
        SellSessionChanged():
      return SellFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionRequirements(
      sellRequirementsPolicy,
      state.requirements,
      stepEvent,
    ),
    state.requirements,
    (next) => _requirementsNext(state.open, state.amount, state.source, next),
  );
}

/// The visibility event of the requirement being met, if it watches.
RequirementsEvent? requirementsVisibility(
  RequirementsRunning running,
  bool visible,
) => switch (running.current) {
  InteracStep() => null,
  VirtualIbanStep() => RequirementVirtualIbanEvent(
    VibanVisibilityChanged(visible: visible),
  ),
  VirtualPayeeStep() => RequirementVirtualPayeeEvent(
    PayeeVisibilityChanged(visible: visible),
  ),
};

/// Where Back from the order step returns: the payout pick (balance) or the
/// recipients (a recipient), the order released.
SellFlowNext _orderLeft(SellOpen open, SellRequest request) =>
    switch (request.payout) {
      SellToBalance() => SellFlowNext(
        SellPayoutPick(open, request.amount, request.source),
      ),
      SellToRecipient() => SellFlowNext(
        SellRecipient(open, request.amount, request.source),
      ),
    };

SellFlowNext _order(
  SellOpen open,
  SellRequest request,
  OrderStepNext<SellRequest, Order> next, [
  DateTime? committedAt,
]) {
  final effects = [for (final effect in next.effects) SellOrderEffect(effect)];
  return switch (next.state) {
    OrderCommitted(:final quoted) ||
    OrderPlaced(placed: final quoted) => switch (committedAt) {
      final at? => _payin(
        open,
        request,
        quoted,
        payinStart<PayinSpend>(
          sellPayinPolicy,
          order: quoted.order,
          source: request.source,
          now: at,
          openEntry: openPayinEntryFor(quoted.id, open.context.openEntries),
        ),
        effects,
      ),
      // Only Confirm commits (sellOrderPolicy locks), and it carries
      // its time; keep the review otherwise.
      null => SellFlowNext(
        SellOrdering(
          open,
          request,
          OrderQuoted<SellRequest, Order>(quoted, const QuoteLive()),
        ),
      ),
    },
    OrderLeft() => SellFlowNext(_orderLeft(open, request).state, effects),
    OrderSessionEnded() => SellFlowNext(const SellSessionEnded(), effects),
    OrderCreating() ||
    OrderWriteRefused() ||
    OrderCreateFailed() ||
    OrderVerifying() ||
    OrderUnverified() ||
    OrderQuoted() => SellFlowNext(
      SellOrdering(open, request, next.state),
      effects,
    ),
  };
}

SellFlowNext _ordering(SellOrdering state, SellFlowEvent event) {
  final SellOrderEvent stepEvent;
  DateTime? committedAt;
  switch (event) {
    case SellOrderChanged(:final event):
      stepEvent = event;
    case SellRetryPressed():
      stepEvent = const OrderRetryPressed();
    case SellConfirmPressed(:final at):
      stepEvent = const OrderCommitPressed();
      committedAt = at;
    case SellBackPressed():
      stepEvent = const OrderBackPressed();
    case SellContextLoaded() ||
        SellAmountChanged() ||
        SellKycReturned() ||
        SellDetourLoaded() ||
        SellSourcePicked() ||
        SellPayoutPicked() ||
        SellRecipientPicked() ||
        SellRequirementsChanged() ||
        SellPayinChanged() ||
        SellDonePressed() ||
        SellVisibilityChanged() ||
        SellSessionChanged():
      return SellFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionOrderStep(sellOrderPolicy, state.order, stepEvent),
    state.order,
    (next) => _order(state.open, state.request, next, committedAt),
  );
}

/// The flow after the payin answered [next]; [before] are effects of the
/// step that handed over (the quote timers' stop).
SellFlowNext _payin(
  SellOpen open,
  SellRequest request,
  QuotedOrder<Order> quoted,
  PayinNext<PayinSpend> next, [
  List<SellFlowEffect> before = const [],
]) {
  final effects = [
    ...before,
    for (final effect in next.effects) SellPayinEffect(effect),
  ];
  return switch (next.state) {
    PayinCompleted(:final order, :final txid) => SellFlowNext(
      SellDone(open, order, txid),
      effects,
    ),
    // The deadline passed with nothing sent: refresh the quote; Confirm
    // comes back only once it is live again.
    PayinQuoteLapsed(:final order) => SellFlowNext(
      SellOrdering(
        open,
        request,
        OrderQuoted<SellRequest, Order>(
          QuotedOrder(order.orderId, order),
          const QuoteRefreshing(0),
        ),
      ),
      [...effects, SellOrderEffect(OrderRefresh<SellRequest>(order.orderId))],
    ),
    // Nothing was sent: back to the review, the quote refreshed first.
    PayinLeft() => SellFlowNext(
      SellOrdering(
        open,
        request,
        OrderQuoted<SellRequest, Order>(quoted, const QuoteRefreshing(0)),
      ),
      [...effects, SellOrderEffect(OrderRefresh<SellRequest>(quoted.id))],
    ),
    PayinLeftPending() => SellFlowNext(const SellClosed(), effects),
    PayinSessionEnded() => SellFlowNext(const SellSessionEnded(), effects),
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
    PayinRefusedByExchange() ||
    PayinOrderEnded() ||
    PayinDepositRefused() => SellFlowNext(
      SellPaying(open, request, quoted, next.state),
      effects,
    ),
  };
}

SellFlowNext _paying(SellPaying state, SellFlowEvent event) {
  final SellPayinEvent stepEvent;
  switch (event) {
    case SellPayinChanged(:final event):
      stepEvent = event;
    case SellRetryPressed():
      stepEvent = const PayinRetryPressed();
    case SellBackPressed():
      // The payin's own ends (refused, order ended, deposit refused) are
      // terminal there: Back leaves the flow, never offers a new send.
      switch (state.payin) {
        case PayinRefusedByExchange() ||
            PayinOrderEnded() ||
            PayinDepositRefused():
          return _closed;
        case PayinBuilding() ||
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
            PayinSessionEnded():
          stepEvent = const PayinBackPressed();
      }
    case SellDonePressed():
      switch (state.payin) {
        case PayinRefusedByExchange() ||
            PayinOrderEnded() ||
            PayinDepositRefused():
          return _closed;
        case PayinBuilding() ||
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
            PayinSessionEnded():
          return SellFlowNext.stay(state);
      }
    case SellVisibilityChanged(:final visible):
      stepEvent = PayinWatchEvent(WatchVisibilityChanged(visible: visible));
    case SellContextLoaded() ||
        SellAmountChanged() ||
        SellKycReturned() ||
        SellDetourLoaded() ||
        SellSourcePicked() ||
        SellPayoutPicked() ||
        SellRecipientPicked() ||
        SellRequirementsChanged() ||
        SellOrderChanged() ||
        SellConfirmPressed() ||
        SellSessionChanged():
      return SellFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionPayin(sellPayinPolicy, state.payin, stepEvent),
    state.payin,
    (next) => _payin(state.open, state.request, state.quoted, next),
  );
}

SellFlowNext _terminal(SellFlowState state, SellFlowEvent event) =>
    switch (event) {
      SellDonePressed() || SellBackPressed() => _closed,
      SellContextLoaded() ||
      SellRetryPressed() ||
      SellAmountChanged() ||
      SellKycReturned() ||
      SellDetourLoaded() ||
      SellSourcePicked() ||
      SellPayoutPicked() ||
      SellRecipientPicked() ||
      SellRequirementsChanged() ||
      SellOrderChanged() ||
      SellConfirmPressed() ||
      SellPayinChanged() ||
      SellVisibilityChanged() ||
      SellSessionChanged() => SellFlowNext.stay(state),
    };
