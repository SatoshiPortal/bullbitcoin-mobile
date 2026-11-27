import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/spend_options_state.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'sell_effect.dart';
import 'sell_event.dart';

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
      listsEqual(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));

  @override
  String toString() => '$runtimeType';

  SellFlowNext next(SellFlowEvent event) {
    final state = this;
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
}

/// The account and the open journal entries: an order with an open payin
/// entry starts its payin in Verifying, never offering the send again.
@immutable
final class SellContext {
  final UserSummary summary;
  final List<UnknownWrite> openEntries;

  /// The order limits the exchange answered in this flow, per currency:
  /// the amount step checks them before the next order.
  final Map<FiatCurrency, AmountLimits> limits;

  const SellContext(this.summary, this.openEntries, {this.limits = const {}});

  AmountContext get amountContext => AmountContext(
    kycGroups: summary.kycGroups,
    balances: const {},
    limits: limits,
  );

  /// This context, knowing the order limit the exchange refused for.
  SellContext withExchangeLimit(ExchangeOrderLimit limit) => SellContext(
    summary,
    openEntries,
    limits: amountContext.withExchangeLimit(limit).limits,
  );

  /// [loaded] (a reload), keeping the limits this flow learned.
  SellContext withAccount(SellContext loaded) =>
      SellContext(loaded.summary, loaded.openEntries, limits: limits);

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
      identical(other.openEntries, openEntries) &&
      _sameLimits(other.limits, limits);

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

typedef SellPayinState = PayinState<PayinSpend>;

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

  /// How the payin will be built, chosen on the review.
  final SpendOptionsState spend;

  const SellOrdering(this.open, this.request, this.order, this.spend);

  @override
  List<Object?> get _props => [open, request, order, spend];
}

/// Paying the committed order in.
final class SellPaying extends SellFlowState {
  final SellOpen open;
  final SellRequest request;
  final QuotedOrder<Order> quoted;

  /// Never [PayinCompleted], [PayinQuoteLapsed], [PayinLeft],
  /// [PayinLeftPending] or [PayinSessionEnded].
  final SellPayinState payin;

  /// The options the payin started with; Back to the review keeps them.
  final SpendOptionsState spend;

  const SellPaying(
    this.open,
    this.request,
    this.quoted,
    this.payin,
    this.spend,
  );

  @override
  List<Object?> get _props => [open, request, quoted, payin, spend];
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
        SellSpendChanged() ||
        SellVisibilityChanged() ||
        SellSessionChanged():
      return SellFlowNext.stay(state);
  }
  final next = state.load.next(loadEvent);
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
    state.amount.next(sellAmountPolicy, event),
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
      Ok(value: final context) => _amountNext(
        SellOpen(state.open.session, state.open.context.withAccount(context)),
        state.amount.next(
          sellAmountPolicy,
          AmountDetourReturned(context.amountContext),
        ),
      ),
      Err(failure: ExchangeSessionRejectedFailure()) => _ended,
      // The detour page stays; returning again reads again.
      Err(failure: ExchangeMissingFailure()) ||
      Err(failure: ExchangeUnreachableFailure()) ||
      Err(failure: ExchangeMalformedFailure()) => SellFlowNext.stay(state),
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
  SellSpendChanged() ||
  SellDonePressed() ||
  SellVisibilityChanged() ||
  SellSessionChanged() => SellFlowNext.stay(state),
};

/// The exchange refused [request]'s amount for [limit]: back to the amount
/// with the draft, the limit known to the step from now on.
SellFlowNext _amountRefused(
  SellOpen open,
  SellRequest request,
  ExchangeOrderLimit limit,
) {
  final learned = SellOpen(open.session, open.context.withExchangeLimit(limit));
  return _amountNext(
    learned,
    AmountDone(
      request.amount,
      learned.context.amountContext,
    ).next(sellAmountPolicy, AmountLimitRefused(limit)),
  );
}

/// Back to the amount with the entered draft kept.
SellFlowNext _editAmount(SellOpen open, EnteredAmount amount) => _amountNext(
  open,
  AmountDone(
    amount,
    open.context.amountContext,
  ).next(sellAmountPolicy, const AmountEditRequested()),
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
  SellSpendChanged() ||
  SellDonePressed() ||
  SellVisibilityChanged() ||
  SellSessionChanged() => SellFlowNext.stay(state),
};

SellFlowNext _payout(SellPayoutPick state, SellFlowEvent event) =>
    switch (event) {
      SellPayoutPicked(choice: SellPayoutChoice.balance) => _startOrder(
        state.open,
        SellRequest(state.amount, state.source, const SellToBalance()),
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
      SellSpendChanged() ||
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
      SellSpendChanged() ||
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
  RequirementsReady(:final ready) => _startOrder(
    open,
    SellRequest(amount, source, SellToRecipient(ready)),
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
        SellSpendChanged() ||
        SellDonePressed() ||
        SellSessionChanged():
      return SellFlowNext.stay(state);
  }
  return _stepped(
    state,
    state.requirements.next(sellRequirementsPolicy, stepEvent),
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

/// The order step of a new order: the spend options start beside it.
SellFlowNext _startOrder(SellOpen open, SellRequest request) {
  final spend = spendOptionsStart(request.source);
  final next = _order(
    open,
    request,
    spend.state,
    orderCreateStart<SellRequest, Order>(request),
  );
  return SellFlowNext(next.state, [
    ...next.effects,
    for (final effect in spend.effects) SellSpendEffect(effect),
  ]);
}

/// The order step in [order]; a quote points the spend options' previews at
/// its deposit and amount.
SellFlowNext _review(
  SellOpen open,
  SellRequest request,
  SellOrderState order,
  SpendOptionsState spend,
  List<SellFlowEffect> effects,
) {
  if (order case OrderQuoted(:final quoted)) {
    final synced = spendTargetFor(spend, quoted.order, request.source);
    return SellFlowNext(SellOrdering(open, request, order, synced.state), [
      ...effects,
      for (final effect in synced.effects) SellSpendEffect(effect),
    ]);
  }
  return SellFlowNext(SellOrdering(open, request, order, spend), effects);
}

SellFlowNext _order(
  SellOpen open,
  SellRequest request,
  SpendOptionsState spend,
  OrderStepNext<SellRequest, Order> next, [
  ({DateTime at, PayinSpendOptions? options})? commit,
]) {
  final effects = [for (final effect in next.effects) SellOrderEffect(effect)];
  return switch (next.state) {
    OrderCommitted(:final quoted) ||
    OrderPlaced(placed: final quoted) => switch (commit) {
      (:final at, :final options)? => _payin(
        open,
        request,
        quoted,
        spend,
        payinStart<PayinSpend>(
          sellPayinPolicy,
          order: quoted.order,
          source: request.source,
          now: at,
          options: options,
          openEntry: openPayinEntryFor(quoted.id, open.context.openEntries),
        ),
        effects,
      ),
      // Only Confirm commits (sellOrderPolicy locks), and it carries
      // its time; keep the review otherwise.
      null => _review(
        open,
        request,
        OrderQuoted<SellRequest, Order>(quoted, const QuoteLive()),
        spend,
        const [],
      ),
    },
    OrderLeft() => SellFlowNext(_orderLeft(open, request).state, effects),
    // Retry would send the same amount: back to it, with the limit shown.
    OrderAmountRefused(:final limit) => _amountRefused(open, request, limit),
    OrderSessionEnded() => SellFlowNext(const SellSessionEnded(), effects),
    OrderCreating() ||
    OrderWriteRefused() ||
    OrderCreateFailed() ||
    OrderVerifying() ||
    OrderUnverified() ||
    OrderQuoted() => _review(open, request, next.state, spend, effects),
  };
}

SellFlowNext _ordering(SellOrdering state, SellFlowEvent event) {
  final SellOrderEvent stepEvent;
  ({DateTime at, PayinSpendOptions? options})? commit;
  switch (event) {
    case SellOrderChanged(:final event):
      stepEvent = event;
    case SellSpendChanged(:final event):
      var spend = state.spend.next(event);
      if (state.order case OrderQuoted(:final quoted)) {
        final synced = spendTargetFor(
          spend.state,
          quoted.order,
          state.request.source,
        );
        spend = SpendOptionsNext(synced.state, [
          ...spend.effects,
          ...synced.effects,
        ]);
      }
      if (spend.state == state.spend && spend.effects.isEmpty) {
        return SellFlowNext.stay(state);
      }
      return SellFlowNext(
        SellOrdering(state.open, state.request, state.order, spend.state),
        [for (final effect in spend.effects) SellSpendEffect(effect)],
      );
    case SellRetryPressed():
      stepEvent = const OrderRetryPressed();
    // Confirm needs the spend options: never a default fee.
    case SellConfirmPressed(:final at):
      switch (spendOptionsChosen(state.spend)) {
        case SpendNotChosen():
          return SellFlowNext.stay(state);
        case SpendChosen(:final options):
          commit = (at: at, options: options);
      }
      stepEvent = const OrderCommitPressed();
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
    state.order.next(sellOrderPolicy, stepEvent),
    state.order,
    (next) => _order(state.open, state.request, state.spend, next, commit),
  );
}

/// The flow after the payin answered [next]; [before] are effects of the
/// step that handed over (the quote timers' stop).
SellFlowNext _payin(
  SellOpen open,
  SellRequest request,
  QuotedOrder<Order> quoted,
  SpendOptionsState spend,
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
        spend,
      ),
      [...effects, SellOrderEffect(OrderRefresh<SellRequest>(order.orderId))],
    ),
    // Nothing was sent: back to the review, the quote refreshed first.
    PayinLeft() => SellFlowNext(
      SellOrdering(
        open,
        request,
        OrderQuoted<SellRequest, Order>(quoted, const QuoteRefreshing(0)),
        spend,
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
      SellPaying(open, request, quoted, next.state, spend),
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
        SellSpendChanged() ||
        SellSessionChanged():
      return SellFlowNext.stay(state);
  }
  return _stepped(
    state,
    state.payin.next(sellPayinPolicy, stepEvent),
    state.payin,
    (next) =>
        _payin(state.open, state.request, state.quoted, state.spend, next),
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
      SellSpendChanged() ||
      SellVisibilityChanged() ||
      SellSessionChanged() => SellFlowNext.stay(state),
    };

bool _sameLimits(
  Map<FiatCurrency, AmountLimits> a,
  Map<FiatCurrency, AmountLimits> b,
) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
