import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

/// The pay flow (composition §5, Pay column): session → account load →
/// recipient (any rail, anyone's) → its payout requirements → amount in the
/// recipient's currency with a description → payin source → order create
/// and quote → payin → done, or for a SINPE payout a bounded watch for the
/// receipt.
@immutable
sealed class PayFlowState {
  const PayFlowState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is PayFlowState &&
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

@immutable
final class PayContext {
  final UserSummary summary;
  final List<UnknownWrite> openEntries;

  const PayContext(this.summary, this.openEntries);

  AmountContext get amountContext =>
      AmountContext(kycGroups: summary.kycGroups, balances: const {});

  @override
  bool operator ==(Object other) =>
      other is PayContext &&
      other.summary == summary &&
      identical(other.openEntries, openEntries);

  @override
  int get hashCode => Object.hash(summary, openEntries.length);
}

@immutable
final class PayOpen {
  final ExchangeSession session;
  final PayContext context;

  const PayOpen(this.session, this.context);

  @override
  bool operator ==(Object other) =>
      other is PayOpen && other.session == session && other.context == context;

  @override
  int get hashCode => Object.hash(session, context);
}

/// The order create: the entered amount to the ready recipient, paid in
/// from [source], with the recipient's payout params (Interac answer
/// included when the rail asks for one).
@immutable
final class PayRequest {
  final ReadyRecipient recipient;
  final EnteredAmount amount;
  final PayinSource source;

  const PayRequest(this.recipient, this.amount, this.source);

  OrderPayoutParams get payout => recipient.orderParams;

  OrderCreateJournalRequest get journal => OrderCreateJournalRequest(
    type: OrderType.fiatPayment,
    amount: FiatAmount(amount.fiat),
    currency: amount.market.currency,
    recipientId: payout.recipientId,
  );

  @override
  bool operator ==(Object other) =>
      other is PayRequest &&
      other.recipient == recipient &&
      other.amount == amount &&
      other.source == source;

  @override
  int get hashCode => Object.hash(recipient, amount, source);
}

/// Pay's amount policy: the recipient's currency, fiat, with a
/// description; the KYC level checked against the market's limits.
AmountPolicy payAmountPolicy(Market market) => AmountPolicy(
  currencySource: CurrencyFixed(market),
  allowBitcoinUnit: false,
  checkBalance: false,
  onShortfall: BalanceShortfall.block,
  checkKyc: true,
  withDescription: true,
);

String _orderId(Order order) => order.orderId;

const payOrderPolicy = OrderPolicy<Order>(idOf: _orderId, locks: true);

const payRequirementsPolicy = RequirementsPolicy();

const payPayinPolicy = PayinPolicy(
  maxPolls: 120,
  maxDuration: Duration(minutes: 10),
  maxUnreadable: 5,
);

/// Anyone's recipient on any payout rail.
const payRecipientFilter = RecipientFilter(rails: PayoutRails.all);

/// The SINPE receipt watch: done once the payout completed, failed when it
/// was cancelled or failed; bounded like every watch.
OutcomeVerdict payReceiptVerdict(Order order) => switch (order.payoutStatus) {
  OrderPayoutStatus.completed => OutcomeVerdict.done,
  OrderPayoutStatus.canceled ||
  OrderPayoutStatus.failed => OutcomeVerdict.failed,
  OrderPayoutStatus.notStarted ||
  OrderPayoutStatus.inProgress ||
  OrderPayoutStatus.scheduled ||
  OrderPayoutStatus.awaitingClaim ||
  OrderPayoutStatus.unknown => OutcomeVerdict.pending,
};

bool _hasReceipt(Order order) =>
    order.payoutStatus == OrderPayoutStatus.completed;

final payReceiptPolicy = OutcomePolicy<Order>(
  idOf: _orderId,
  verdictOf: payReceiptVerdict,
  hasReceipt: _hasReceipt,
  maxPolls: 20,
  maxDuration: const Duration(minutes: 10),
  maxUnreadable: 5,
);

/// A SINPE Móvil payout has a receipt the flow waits for.
bool payHasReceipt(Order order) =>
    order.payoutMethod == OrderPaymentMethod.sinpe;

typedef PayOrderState = OrderStepState<PayRequest, Order>;
typedef PayOrderEvent = OrderStepEvent<PayRequest, Order>;
typedef PayPayinState = PayinState<PayinSpend>;
typedef PayPayinEvent = PayinEvent<PayinSpend>;

final class PayLoading extends PayFlowState {
  final ExchangeSession session;
  final ContextLoadState<PayContext> load;

  const PayLoading(this.session, this.load);

  @override
  List<Object?> get _props => [session, load];
}

/// Picking the recipient; [refused] is the last one the filter refused.
final class PayRecipient extends PayFlowState {
  final PayOpen open;
  final Recipient? refused;

  const PayRecipient(this.open, {this.refused});

  @override
  List<Object?> get _props => [open, refused];
}

final class PayRequirements extends PayFlowState {
  final PayOpen open;
  final RequirementsRunning requirements;

  const PayRequirements(this.open, this.requirements);

  @override
  List<Object?> get _props => [open, requirements];
}

final class PayAmount extends PayFlowState {
  final PayOpen open;
  final ReadyRecipient recipient;

  /// Never [AmountDone] or [AmountSessionRejected].
  final AmountEntryState amount;

  const PayAmount(this.open, this.recipient, this.amount);

  AmountPolicy get policy => payAmountPolicy(recipient.rail.market);

  @override
  List<Object?> get _props => [open, recipient, amount];
}

final class PaySource extends PayFlowState {
  final PayOpen open;
  final ReadyRecipient recipient;
  final EnteredAmount amount;

  const PaySource(this.open, this.recipient, this.amount);

  @override
  List<Object?> get _props => [open, recipient, amount];
}

/// Creating the order and holding its quote; [OrderQuoted] is the review.
final class PayOrdering extends PayFlowState {
  final PayOpen open;
  final PayRequest request;

  /// Never [OrderPlaced], [OrderCommitted], [OrderLeft] or
  /// [OrderSessionEnded].
  final PayOrderState order;

  /// How the payin will be built, chosen on the review.
  final SpendOptionsState spend;

  const PayOrdering(this.open, this.request, this.order, this.spend);

  @override
  List<Object?> get _props => [open, request, order, spend];
}

final class PayPaying extends PayFlowState {
  final PayOpen open;
  final PayRequest request;
  final QuotedOrder<Order> quoted;

  /// Never [PayinCompleted], [PayinQuoteLapsed], [PayinLeft],
  /// [PayinLeftPending] or [PayinSessionEnded].
  final PayPayinState payin;

  /// The options the payin started with; Back to the review keeps them.
  final SpendOptionsState spend;

  const PayPaying(this.open, this.request, this.quoted, this.payin, this.spend);

  @override
  List<Object?> get _props => [open, request, quoted, payin, spend];
}

/// The exchange received the payin, and for a SINPE payout the receipt
/// watch: [receipt] is null for other rails.
final class PayDone extends PayFlowState {
  final PayOpen open;
  final Order order;
  final String? txid;
  final OutcomeWatchState<Order>? receipt;

  const PayDone(this.open, this.order, this.txid, this.receipt);

  /// The latest order the receipt watch read.
  Order get latest => switch (receipt) {
    null || WatchSessionEnded() || WatchLeft() => order,
    WatchWatching(:final order) ||
    WatchPaused(:final order) ||
    WatchDone(:final order) ||
    WatchReceipt(:final order) ||
    WatchFailed(:final order) ||
    WatchUnreadable(:final order) ||
    WatchTimedOut(:final order) => order,
  };

  @override
  List<Object?> get _props => [open, order.orderId, txid, receipt];
}

final class PaySessionEnded extends PayFlowState {
  const PaySessionEnded();

  @override
  List<Object?> get _props => const [];
}

final class PayClosed extends PayFlowState {
  const PayClosed();

  @override
  List<Object?> get _props => const [];
}

@immutable
sealed class PayFlowEvent {
  const PayFlowEvent();
}

final class PayContextLoaded extends PayFlowEvent {
  final int attempt;
  final ExchangeRead<PayContext> read;

  const PayContextLoaded(this.attempt, this.read);
}

final class PayRetryPressed extends PayFlowEvent {
  const PayRetryPressed();
}

final class PayRecipientPicked extends PayFlowEvent {
  final Recipient recipient;

  const PayRecipientPicked(this.recipient);
}

final class PayRequirementsChanged extends PayFlowEvent {
  final RequirementsEvent event;

  const PayRequirementsChanged(this.event);
}

final class PayAmountChanged extends PayFlowEvent {
  final AmountEntryEvent event;

  const PayAmountChanged(this.event);
}

final class PayKycReturned extends PayFlowEvent {
  const PayKycReturned();
}

final class PayDetourLoaded extends PayFlowEvent {
  final ExchangeRead<PayContext> read;

  const PayDetourLoaded(this.read);
}

final class PaySourcePicked extends PayFlowEvent {
  final PayinSource source;

  const PaySourcePicked(this.source);
}

final class PayOrderChanged extends PayFlowEvent {
  final PayOrderEvent event;

  const PayOrderChanged(this.event);
}

/// Confirm on a live quote, [at] the time pressed.
final class PayConfirmPressed extends PayFlowEvent {
  final DateTime at;

  const PayConfirmPressed(this.at);
}

/// A change of the review's spend options (or one of their answers).
final class PaySpendChanged extends PayFlowEvent {
  final SpendOptionsEvent event;

  const PaySpendChanged(this.event);
}

final class PayPayinChanged extends PayFlowEvent {
  final PayPayinEvent event;

  const PayPayinChanged(this.event);
}

final class PayReceiptChanged extends PayFlowEvent {
  final OutcomeWatchEvent<Order> event;

  const PayReceiptChanged(this.event);
}

final class PayBackPressed extends PayFlowEvent {
  const PayBackPressed();
}

final class PayDonePressed extends PayFlowEvent {
  const PayDonePressed();
}

final class PayVisibilityChanged extends PayFlowEvent {
  final bool visible;

  const PayVisibilityChanged({required this.visible});
}

final class PaySessionChanged extends PayFlowEvent {
  final ExchangeSession? session;

  const PaySessionChanged(this.session);
}

@immutable
sealed class PayFlowEffect {
  const PayFlowEffect();

  Object get _value;

  @override
  bool operator ==(Object other) =>
      other is PayFlowEffect &&
      other.runtimeType == runtimeType &&
      other._value == _value;

  @override
  int get hashCode => Object.hash(runtimeType, _value);

  @override
  String toString() => '$runtimeType($_value)';
}

final class PayLoadContext extends PayFlowEffect {
  final int attempt;

  const PayLoadContext(this.attempt);

  @override
  Object get _value => attempt;
}

final class PayReloadForDetour extends PayFlowEffect {
  const PayReloadForDetour();

  @override
  Object get _value => 0;
}

final class PayFetchRate extends PayFlowEffect {
  final Market market;

  const PayFetchRate(this.market);

  @override
  Object get _value => market;
}

final class PayRequirementsEffect extends PayFlowEffect {
  final RequirementsEffect effect;

  const PayRequirementsEffect(this.effect);

  @override
  Object get _value => effect;
}

final class PayOrderEffect extends PayFlowEffect {
  final OrderStepEffect<PayRequest> effect;

  const PayOrderEffect(this.effect);

  @override
  Object get _value => effect;
}

final class PaySpendEffect extends PayFlowEffect {
  final SpendOptionsEffect effect;

  const PaySpendEffect(this.effect);

  @override
  Object get _value => effect;
}

final class PayPayinEffect extends PayFlowEffect {
  final PayinEffect<PayinSpend> effect;

  const PayPayinEffect(this.effect);

  @override
  Object get _value => effect;
}

final class PayReceiptEffect extends PayFlowEffect {
  final OutcomeWatchEffect effect;

  const PayReceiptEffect(this.effect);

  @override
  Object get _value => effect;
}

typedef PayFlowNext = StepNext<PayFlowState, PayFlowEffect>;

const _ended = PayFlowNext(PaySessionEnded());
const _closed = PayFlowNext(PayClosed());

PayFlowNext payFlowStart(ExchangeSession? session) => switch (session) {
  final session? => PayFlowNext(PayLoading(session, const ContextLoading(1)), [
    const PayLoadContext(1),
  ]),
  null => _ended,
};

PayFlowNext transitionPayFlow(PayFlowState state, PayFlowEvent event) {
  if (event case PaySessionChanged(:final session)) {
    final current = _sessionOf(state);
    return current != null && current != session
        ? PayFlowNext(const PaySessionEnded(), _stopAll(state))
        : PayFlowNext.stay(state);
  }
  return switch (state) {
    PayLoading() => _loading(state, event),
    PayRecipient() => _recipient(state, event),
    PayRequirements() => _requirements(state, event),
    PayAmount() => _amount(state, event),
    PaySource() => _source(state, event),
    PayOrdering() => _ordering(state, event),
    PayPaying() => _paying(state, event),
    PayDone() => _done(state, event),
    PaySessionEnded() => _terminal(state, event),
    PayClosed() => PayFlowNext.stay(state),
  };
}

ExchangeSession? _sessionOf(PayFlowState state) => switch (state) {
  PayLoading(:final session) => session,
  PayRecipient(:final open) ||
  PayRequirements(:final open) ||
  PayAmount(:final open) ||
  PaySource(:final open) ||
  PayOrdering(:final open) ||
  PayPaying(:final open) ||
  PayDone(:final open) => open.session,
  PaySessionEnded() || PayClosed() => null,
};

List<PayFlowEffect> _stopAll(PayFlowState state) => switch (state) {
  PayOrdering(order: OrderQuoted(:final quoted)) => [
    PayOrderEffect(OrderStopTimers(quoted.id)),
  ],
  PayPaying(:final quoted, :final payin) => [
    if (payin
        case PayinPayjoinNegotiating(:final sessionId) ||
            PayinPayjoinPaused(:final sessionId))
      PayPayinEffect(PayinStopPayjoin(sessionId)),
    PayPayinEffect(PayinWatchEffect(WatchStop(quoted.id))),
  ],
  PayDone(:final order, receipt: _?) => [
    PayReceiptEffect(WatchStop(order.orderId)),
  ],
  PayLoading() ||
  PayRecipient() ||
  PayRequirements() ||
  PayAmount() ||
  PaySource() ||
  PayOrdering() ||
  PayDone() ||
  PaySessionEnded() ||
  PayClosed() => const [],
};

PayFlowNext _stepped<S, F>(
  PayFlowState flow,
  StepNext<S, F> next,
  S current,
  PayFlowNext Function(StepNext<S, F> next) map,
) => identical(next.state, current) && next.effects.isEmpty
    ? PayFlowNext.stay(flow)
    : map(next);

PayFlowNext _loading(PayLoading state, PayFlowEvent event) {
  final ContextLoadEvent<PayContext> loadEvent;
  switch (event) {
    case PayContextLoaded(:final attempt, :final read):
      loadEvent = ContextLoaded(attempt, read);
    case PayRetryPressed():
      loadEvent = const ContextRetryPressed();
    case PayBackPressed() || PayDonePressed():
      return _closed;
    case PayRecipientPicked() ||
        PayRequirementsChanged() ||
        PayAmountChanged() ||
        PayKycReturned() ||
        PayDetourLoaded() ||
        PaySourcePicked() ||
        PayOrderChanged() ||
        PayConfirmPressed() ||
        PayPayinChanged() ||
        PaySpendChanged() ||
        PayReceiptChanged() ||
        PayVisibilityChanged() ||
        PaySessionChanged():
      return PayFlowNext.stay(state);
  }
  final next = transitionContextLoad(state.load, loadEvent);
  if (identical(next.state, state.load)) return PayFlowNext.stay(state);
  return switch (next.state) {
    ContextReady(:final context) => PayFlowNext(
      PayRecipient(PayOpen(state.session, context)),
    ),
    ContextSessionRejected() => _ended,
    ContextLoading() || ContextFailed() => PayFlowNext(
      PayLoading(state.session, next.state),
      [
        for (final effect in next.effects)
          switch (effect) {
            ContextFetch(:final attempt) => PayLoadContext(attempt),
          },
      ],
    ),
  };
}

PayFlowNext _recipient(PayRecipient state, PayFlowEvent event) =>
    switch (event) {
      PayRecipientPicked(:final recipient) => switch (payRecipientFilter.choose(
        recipient,
      )) {
        final chosen? => _requirementsNext(
          state.open,
          requirementsStart(payRequirementsPolicy, chosen, PayoutPurpose.pay),
        ),
        null => PayFlowNext(PayRecipient(state.open, refused: recipient)),
      },
      PayBackPressed() => _closed,
      PayContextLoaded() ||
      PayRetryPressed() ||
      PayRequirementsChanged() ||
      PayAmountChanged() ||
      PayKycReturned() ||
      PayDetourLoaded() ||
      PaySourcePicked() ||
      PayOrderChanged() ||
      PayConfirmPressed() ||
      PayPayinChanged() ||
      PaySpendChanged() ||
      PayReceiptChanged() ||
      PayDonePressed() ||
      PayVisibilityChanged() ||
      PaySessionChanged() => PayFlowNext.stay(state),
    };

PayFlowNext _requirementsNext(PayOpen open, RequirementsNext next) =>
    switch (next.state) {
      RequirementsReady(:final ready) => _amountNext(
        open,
        ready,
        amountEntryStart(
          payAmountPolicy(ready.rail.market),
          open.context.amountContext,
        ),
      ),
      RequirementsCancelled() => PayFlowNext(PayRecipient(open)),
      RequirementsSessionEnded() => _ended,
      final RequirementsRunning running => PayFlowNext(
        PayRequirements(open, running),
        [for (final effect in next.effects) PayRequirementsEffect(effect)],
      ),
    };

PayFlowNext _requirements(PayRequirements state, PayFlowEvent event) {
  final RequirementsEvent stepEvent;
  switch (event) {
    case PayRequirementsChanged(:final event):
      stepEvent = event;
    case PayBackPressed():
      stepEvent = const RequirementsCancelPressed();
    case PayVisibilityChanged(:final visible):
      final visibility = _visibility(state.requirements, visible);
      if (visibility == null) return PayFlowNext.stay(state);
      stepEvent = visibility;
    case PayContextLoaded() ||
        PayRetryPressed() ||
        PayRecipientPicked() ||
        PayAmountChanged() ||
        PayKycReturned() ||
        PayDetourLoaded() ||
        PaySourcePicked() ||
        PayOrderChanged() ||
        PayConfirmPressed() ||
        PayPayinChanged() ||
        PaySpendChanged() ||
        PayReceiptChanged() ||
        PayDonePressed() ||
        PaySessionChanged():
      return PayFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionRequirements(
      payRequirementsPolicy,
      state.requirements,
      stepEvent,
    ),
    state.requirements,
    (next) => _requirementsNext(state.open, next),
  );
}

RequirementsEvent? _visibility(RequirementsRunning running, bool visible) =>
    switch (running.current) {
      InteracStep() => null,
      VirtualIbanStep() => RequirementVirtualIbanEvent(
        VibanVisibilityChanged(visible: visible),
      ),
      VirtualPayeeStep() => RequirementVirtualPayeeEvent(
        PayeeVisibilityChanged(visible: visible),
      ),
    };

PayFlowNext _amountNext(
  PayOpen open,
  ReadyRecipient recipient,
  AmountEntryNext next,
) => switch (next.state) {
  AmountDone(:final amount) => PayFlowNext(PaySource(open, recipient, amount)),
  AmountSessionRejected() => _ended,
  AmountNoMarket() ||
  AmountEditing() ||
  AmountKycDetour() ||
  AmountFundingDetour() => PayFlowNext(PayAmount(open, recipient, next.state), [
    for (final effect in next.effects)
      ...switch (effect) {
        AmountFetchRate(:final market) => [PayFetchRate(market)],
        AmountOpenKyc() || AmountOpenFunding() => const <PayFlowEffect>[],
      },
  ]),
};

PayFlowNext _amount(PayAmount state, PayFlowEvent event) => switch (event) {
  PayAmountChanged(:final event) => _stepped(
    state,
    transitionAmountEntry(state.policy, state.amount, event),
    state.amount,
    (next) => _amountNext(state.open, state.recipient, next),
  ),
  PayKycReturned() => switch (state.amount) {
    AmountKycDetour() => PayFlowNext(state, const [PayReloadForDetour()]),
    AmountNoMarket() ||
    AmountEditing() ||
    AmountFundingDetour() ||
    AmountDone() ||
    AmountSessionRejected() => PayFlowNext.stay(state),
  },
  PayDetourLoaded(:final read) => switch (state.amount) {
    AmountKycDetour() => switch (read) {
      ReadGot(value: final context) => _amountNext(
        PayOpen(state.open.session, context),
        state.recipient,
        transitionAmountEntry(
          state.policy,
          state.amount,
          AmountDetourReturned(context.amountContext),
        ),
      ),
      ReadSessionRejected() => _ended,
      ReadMissing() ||
      ReadUnreachable() ||
      ReadMalformed() => PayFlowNext.stay(state),
    },
    AmountNoMarket() ||
    AmountEditing() ||
    AmountFundingDetour() ||
    AmountDone() ||
    AmountSessionRejected() => PayFlowNext.stay(state),
  },
  PayBackPressed() => PayFlowNext(PayRecipient(state.open)),
  PayContextLoaded() ||
  PayRetryPressed() ||
  PayRecipientPicked() ||
  PayRequirementsChanged() ||
  PaySourcePicked() ||
  PayOrderChanged() ||
  PayConfirmPressed() ||
  PayPayinChanged() ||
  PaySpendChanged() ||
  PayReceiptChanged() ||
  PayDonePressed() ||
  PayVisibilityChanged() ||
  PaySessionChanged() => PayFlowNext.stay(state),
};

/// Back to the amount with the entered draft kept.
PayFlowNext _editAmount(
  PayOpen open,
  ReadyRecipient recipient,
  EnteredAmount amount,
) => _amountNext(
  open,
  recipient,
  transitionAmountEntry(
    payAmountPolicy(recipient.rail.market),
    AmountDone(amount, open.context.amountContext),
    const AmountEditRequested(),
  ),
);

/// Whether [source] can pay in (as sell).
bool _sourceAllowed(PayinSource source) => switch (source) {
  PayinFromAppWallet(:final rail) => rail.rail.canBeAppWallet,
  PayinFromExternal(:final rail) => rail.rail.canBeExternalPayin,
};

PayFlowNext _source(PaySource state, PayFlowEvent event) => switch (event) {
  PaySourcePicked(:final source) =>
    _sourceAllowed(source)
        ? _startOrder(
            state.open,
            PayRequest(state.recipient, state.amount, source),
          )
        : PayFlowNext.stay(state),
  PayBackPressed() => _editAmount(state.open, state.recipient, state.amount),
  PayContextLoaded() ||
  PayRetryPressed() ||
  PayRecipientPicked() ||
  PayRequirementsChanged() ||
  PayAmountChanged() ||
  PayKycReturned() ||
  PayDetourLoaded() ||
  PayOrderChanged() ||
  PayConfirmPressed() ||
  PayPayinChanged() ||
  PaySpendChanged() ||
  PayReceiptChanged() ||
  PayDonePressed() ||
  PayVisibilityChanged() ||
  PaySessionChanged() => PayFlowNext.stay(state),
};

/// The order step of a new order: the spend options start beside it.
PayFlowNext _startOrder(PayOpen open, PayRequest request) {
  final spend = spendOptionsStart(request.source);
  final next = _order(
    open,
    request,
    spend.state,
    orderCreateStart<PayRequest, Order>(request),
  );
  return PayFlowNext(next.state, [
    ...next.effects,
    for (final effect in spend.effects) PaySpendEffect(effect),
  ]);
}

/// The order step in [order]; a quote points the spend options' previews at
/// its deposit and amount.
PayFlowNext _review(
  PayOpen open,
  PayRequest request,
  PayOrderState order,
  SpendOptionsState spend,
  List<PayFlowEffect> effects,
) {
  if (order case OrderQuoted(:final quoted)) {
    final synced = spendTargetFor(spend, quoted.order, request.source);
    return PayFlowNext(PayOrdering(open, request, order, synced.state), [
      ...effects,
      for (final effect in synced.effects) PaySpendEffect(effect),
    ]);
  }
  return PayFlowNext(PayOrdering(open, request, order, spend), effects);
}

PayFlowNext _order(
  PayOpen open,
  PayRequest request,
  SpendOptionsState spend,
  OrderStepNext<PayRequest, Order> next, [
  ({DateTime at, PayinSpendOptions? options})? commit,
]) {
  final effects = [for (final effect in next.effects) PayOrderEffect(effect)];
  return switch (next.state) {
    OrderCommitted(:final quoted) ||
    OrderPlaced(placed: final quoted) => switch (commit) {
      (:final at, :final options)? => _payin(
        open,
        request,
        quoted,
        spend,
        payinStart<PayinSpend>(
          payPayinPolicy,
          order: quoted.order,
          source: request.source,
          now: at,
          options: options,
          openEntry: openPayinEntryFor(quoted.id, open.context.openEntries),
        ),
        effects,
      ),
      null => _review(
        open,
        request,
        OrderQuoted<PayRequest, Order>(quoted, const QuoteLive()),
        spend,
        const [],
      ),
    },
    OrderLeft() => PayFlowNext(
      PaySource(open, request.recipient, request.amount),
      effects,
    ),
    OrderSessionEnded() => PayFlowNext(const PaySessionEnded(), effects),
    OrderCreating() ||
    OrderWriteRefused() ||
    OrderCreateFailed() ||
    OrderVerifying() ||
    OrderUnverified() ||
    OrderQuoted() => _review(open, request, next.state, spend, effects),
  };
}

PayFlowNext _ordering(PayOrdering state, PayFlowEvent event) {
  final PayOrderEvent stepEvent;
  ({DateTime at, PayinSpendOptions? options})? commit;
  switch (event) {
    case PayOrderChanged(:final event):
      stepEvent = event;
    case PaySpendChanged(:final event):
      var spend = transitionSpendOptions(state.spend, event);
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
        return PayFlowNext.stay(state);
      }
      return PayFlowNext(
        PayOrdering(state.open, state.request, state.order, spend.state),
        [for (final effect in spend.effects) PaySpendEffect(effect)],
      );
    case PayRetryPressed():
      stepEvent = const OrderRetryPressed();
    // Confirm needs the spend options: never a default fee.
    case PayConfirmPressed(:final at):
      switch (spendOptionsChosen(state.spend)) {
        case SpendNotChosen():
          return PayFlowNext.stay(state);
        case SpendChosen(:final options):
          commit = (at: at, options: options);
      }
      stepEvent = const OrderCommitPressed();
    case PayBackPressed():
      stepEvent = const OrderBackPressed();
    case PayContextLoaded() ||
        PayRecipientPicked() ||
        PayRequirementsChanged() ||
        PayAmountChanged() ||
        PayKycReturned() ||
        PayDetourLoaded() ||
        PaySourcePicked() ||
        PayPayinChanged() ||
        PayReceiptChanged() ||
        PayDonePressed() ||
        PayVisibilityChanged() ||
        PaySessionChanged():
      return PayFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionOrderStep(payOrderPolicy, state.order, stepEvent),
    state.order,
    (next) => _order(state.open, state.request, state.spend, next, commit),
  );
}

PayFlowNext _payin(
  PayOpen open,
  PayRequest request,
  QuotedOrder<Order> quoted,
  SpendOptionsState spend,
  PayinNext<PayinSpend> next, [
  List<PayFlowEffect> before = const [],
]) {
  final effects = [
    ...before,
    for (final effect in next.effects) PayPayinEffect(effect),
  ];
  return switch (next.state) {
    PayinCompleted(:final order, :final txid) =>
      payHasReceipt(order)
          ? _receipt(
              PayDone(open, order, txid, null),
              outcomeWatchStart(payReceiptPolicy, order),
              effects,
            )
          : PayFlowNext(PayDone(open, order, txid, null), effects),
    PayinQuoteLapsed(:final order) => PayFlowNext(
      PayOrdering(
        open,
        request,
        OrderQuoted<PayRequest, Order>(
          QuotedOrder(order.orderId, order),
          const QuoteRefreshing(0),
        ),
        spend,
      ),
      [...effects, PayOrderEffect(OrderRefresh<PayRequest>(order.orderId))],
    ),
    PayinLeft() => PayFlowNext(
      PayOrdering(
        open,
        request,
        OrderQuoted<PayRequest, Order>(quoted, const QuoteRefreshing(0)),
        spend,
      ),
      [...effects, PayOrderEffect(OrderRefresh<PayRequest>(quoted.id))],
    ),
    PayinLeftPending() => PayFlowNext(const PayClosed(), effects),
    PayinSessionEnded() => PayFlowNext(const PaySessionEnded(), effects),
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
    PayinDepositRefused() => PayFlowNext(
      PayPaying(open, request, quoted, next.state, spend),
      effects,
    ),
  };
}

/// Whether [payin] is one of its own ends, where only Leave is offered.
bool _payinEnded(PayPayinState payin) => switch (payin) {
  PayinRefusedByExchange() ||
  PayinOrderEnded() ||
  PayinDepositRefused() => true,
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
  PayinSessionEnded() => false,
};

PayFlowNext _paying(PayPaying state, PayFlowEvent event) {
  final PayPayinEvent stepEvent;
  switch (event) {
    case PayPayinChanged(:final event):
      stepEvent = event;
    case PayRetryPressed():
      stepEvent = const PayinRetryPressed();
    case PayBackPressed():
      if (_payinEnded(state.payin)) return _closed;
      stepEvent = const PayinBackPressed();
    case PayDonePressed():
      return _payinEnded(state.payin) ? _closed : PayFlowNext.stay(state);
    case PayVisibilityChanged(:final visible):
      stepEvent = PayinWatchEvent(WatchVisibilityChanged(visible: visible));
    case PayContextLoaded() ||
        PayRecipientPicked() ||
        PayRequirementsChanged() ||
        PayAmountChanged() ||
        PayKycReturned() ||
        PayDetourLoaded() ||
        PaySourcePicked() ||
        PayOrderChanged() ||
        PayConfirmPressed() ||
        PaySpendChanged() ||
        PayReceiptChanged() ||
        PaySessionChanged():
      return PayFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionPayin(payPayinPolicy, state.payin, stepEvent),
    state.payin,
    (next) =>
        _payin(state.open, state.request, state.quoted, state.spend, next),
  );
}

PayFlowNext _receipt(
  PayDone done,
  OutcomeWatchNext<Order> next, [
  List<PayFlowEffect> before = const [],
]) => switch (next.state) {
  WatchSessionEnded() => PayFlowNext(const PaySessionEnded(), [
    ...before,
    for (final effect in next.effects) PayReceiptEffect(effect),
  ]),
  WatchLeft() => PayFlowNext(const PayClosed(), [
    ...before,
    for (final effect in next.effects) PayReceiptEffect(effect),
  ]),
  WatchWatching() ||
  WatchPaused() ||
  WatchDone() ||
  WatchReceipt() ||
  WatchFailed() ||
  WatchUnreadable() ||
  WatchTimedOut() => PayFlowNext(
    PayDone(done.open, done.order, done.txid, next.state),
    [...before, for (final effect in next.effects) PayReceiptEffect(effect)],
  ),
};

PayFlowNext _done(PayDone state, PayFlowEvent event) {
  final receipt = state.receipt;
  if (receipt == null) return _terminal(state, event);
  final OutcomeWatchEvent<Order> watchEvent;
  switch (event) {
    case PayReceiptChanged(:final event):
      watchEvent = event;
    case PayRetryPressed():
      watchEvent = const WatchRetryPressed();
    case PayVisibilityChanged(:final visible):
      watchEvent = WatchVisibilityChanged(visible: visible);
    case PayDonePressed() || PayBackPressed():
      return PayFlowNext(const PayClosed(), [
        PayReceiptEffect(WatchStop(state.order.orderId)),
      ]);
    case PayContextLoaded() ||
        PayRecipientPicked() ||
        PayRequirementsChanged() ||
        PayAmountChanged() ||
        PayKycReturned() ||
        PayDetourLoaded() ||
        PaySourcePicked() ||
        PayOrderChanged() ||
        PayConfirmPressed() ||
        PayPayinChanged() ||
        PaySpendChanged() ||
        PaySessionChanged():
      return PayFlowNext.stay(state);
  }
  return _stepped(
    state,
    transitionOutcomeWatch(payReceiptPolicy, receipt, watchEvent),
    receipt,
    (next) => _receipt(state, next),
  );
}

PayFlowNext _terminal(PayFlowState state, PayFlowEvent event) =>
    switch (event) {
      PayDonePressed() || PayBackPressed() => _closed,
      PayContextLoaded() ||
      PayRetryPressed() ||
      PayRecipientPicked() ||
      PayRequirementsChanged() ||
      PayAmountChanged() ||
      PayKycReturned() ||
      PayDetourLoaded() ||
      PaySourcePicked() ||
      PayOrderChanged() ||
      PayConfirmPressed() ||
      PayPayinChanged() ||
      PaySpendChanged() ||
      PayReceiptChanged() ||
      PayVisibilityChanged() ||
      PaySessionChanged() => PayFlowNext.stay(state),
    };
