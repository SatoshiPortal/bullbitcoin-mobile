import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The withdraw flow (composition §5, Withdraw column): session → account
/// load → amount from a funded balance → own recipient on the market's rails
/// → payout requirements → order create → review → server confirm → done.
/// Every state holds the session it opened with and only the data valid in
/// it; each step's output is the next step's input, so none can be skipped.
@immutable
sealed class WithdrawFlowState {
  const WithdrawFlowState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is WithdrawFlowState &&
      other.runtimeType == runtimeType &&
      _listEquals(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));

  @override
  String toString() => '$runtimeType';

  WithdrawFlowNext next(WithdrawFlowEvent event) {
    final state = this;
    if (event case WithdrawSessionChanged(:final session)) {
      final current = _sessionOf(state);
      return current != null && current != session
          ? _ended
          : WithdrawFlowNext.stay(state);
    }
    return switch (state) {
      WithdrawLoading() => _loading(state, event),
      WithdrawAmount() => _amount(state, event),
      WithdrawRecipient() => _recipient(state, event),
      WithdrawRequirements() => _requirements(state, event),
      WithdrawOrdering() => _ordering(state, event),
      WithdrawReview() => _review(state, event),
      WithdrawConfirming() => _confirming(state, event),
      WithdrawDone() => _done(state, event),
      WithdrawSessionEnded() => _sessionEnded(state, event),
      WithdrawClosed() => WithdrawFlowNext.stay(state),
    };
  }
}

bool _listEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// What the flow loads before the amount: the account (balances, currency)
/// and the open journal entries, so a confirm whose outcome is still unknown
/// starts in Verifying instead of offering the write again.
@immutable
final class WithdrawContext {
  final UserSummary summary;
  final List<UnknownWrite> openEntries;

  /// The order limits the exchange answered in this flow, per currency:
  /// the amount step checks them before the next order.
  final Map<FiatCurrency, AmountLimits> limits;

  const WithdrawContext(
    this.summary,
    this.openEntries, {
    this.limits = const {},
  });

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
  WithdrawContext withExchangeLimit(ExchangeOrderLimit limit) =>
      WithdrawContext(
        summary,
        openEntries,
        limits: amountContext.withExchangeLimit(limit).limits,
      );

  Market? get preferredMarket => switch (summary.currency) {
    final code? => switch (ExchangeCatalog.parse(code)) {
      KnownCurrency(:final market) => market,
      UnknownCurrency() => null,
    },
    null => null,
  };

  @override
  bool operator ==(Object other) =>
      other is WithdrawContext &&
      other.summary == summary &&
      identical(other.openEntries, openEntries) &&
      _sameLimits(other.limits, limits);

  @override
  int get hashCode => Object.hash(summary, openEntries.length);
}

/// What every state after the account load holds.
@immutable
final class WithdrawOpen {
  final ExchangeSession session;
  final WithdrawContext context;

  const WithdrawOpen(this.session, this.context);

  @override
  bool operator ==(Object other) =>
      other is WithdrawOpen &&
      other.session == session &&
      other.context == context;

  @override
  int get hashCode => Object.hash(session, context);
}

/// The order create the flow sends: the entered amount to the ready
/// recipient, with the recipient's payout params (D10).
@immutable
final class WithdrawRequest {
  final EnteredAmount amount;
  final ReadyRecipient recipient;

  const WithdrawRequest(this.amount, this.recipient);

  OrderPayoutParams get payout => recipient.orderParams;

  /// What the journal records when the create's outcome is unknown.
  OrderCreateJournalRequest get journal => OrderCreateJournalRequest(
    type: OrderType.withdraw,
    amount: FiatAmount(amount.fiat),
    currency: amount.market.currency,
    recipientId: payout.recipientId,
  );

  @override
  bool operator ==(Object other) =>
      other is WithdrawRequest &&
      other.amount == amount &&
      other.recipient == recipient;

  @override
  int get hashCode => Object.hash(amount, recipient);
}

/// The order the server confirm confirms, with the recipient it pays.
@immutable
final class WithdrawConfirmTarget {
  final WithdrawOrder order;
  final ReadyRecipient recipient;

  const WithdrawConfirmTarget(this.order, this.recipient);

  @override
  bool operator ==(Object other) =>
      other is WithdrawConfirmTarget &&
      other.order.orderId == order.orderId &&
      other.recipient == recipient;

  @override
  int get hashCode => Object.hash(order.orderId, recipient);
}

/// Withdraw's amount policy: a funded balance's currency, fiat only, never
/// above the balance. The KYC level check stays on the server for withdraw
/// (product rule), so the step doesn't check it.
const withdrawAmountPolicy = AmountPolicy(
  currencySource: CurrencyFromFundedBalances(),
  allowBitcoinUnit: false,
  checkBalance: true,
  onShortfall: BalanceShortfall.block,
  checkKyc: false,
  withDescription: false,
);

String _withdrawOrderId(WithdrawOrder order) => order.orderId;

/// A withdrawal order has no quote lock: it waits for the confirm.
const withdrawOrderPolicy = OrderPolicy<WithdrawOrder>(
  idOf: _withdrawOrderId,
  locks: false,
);

String _withdrawTargetId(WithdrawConfirmTarget target) => target.order.orderId;

const withdrawConfirmPolicy = ServerConfirmPolicy<WithdrawConfirmTarget>(
  writeKind: FinancialWriteKind.withdrawal,
  journalKind: UnknownWriteKind.withdrawConfirm,
  resourceIdOf: _withdrawTargetId,
);

const withdrawRequirementsPolicy = RequirementsPolicy();

/// The recipients a withdrawal may pay: the user's own, on the market's
/// rails (Confidential SEPA included: it pays out to the user's own account).
RecipientFilter withdrawRecipientFilter(Market market) =>
    RecipientFilter(rails: market.payoutRails, owner: RecipientOwnership.own);

typedef WithdrawOrderState = OrderStepState<WithdrawRequest, WithdrawOrder>;
typedef WithdrawOrderEvent = OrderStepEvent<WithdrawRequest, WithdrawOrder>;
typedef WithdrawConfirmState =
    ServerConfirmState<WithdrawConfirmTarget, WithdrawOrder>;
typedef WithdrawConfirmEvent =
    ServerConfirmEvent<WithdrawConfirmTarget, WithdrawOrder>;

/// Reading the account. Its failure has a Retry.
final class WithdrawLoading extends WithdrawFlowState {
  final ExchangeSession session;

  /// [ContextLoading] or [ContextFailed].
  final ContextLoadState<WithdrawContext> load;

  const WithdrawLoading(this.session, this.load);

  @override
  List<Object?> get _props => [session, load];
}

/// The amount, in the currency of a funded balance.
final class WithdrawAmount extends WithdrawFlowState {
  final WithdrawOpen open;

  /// Never [AmountDone] or [AmountSessionRejected]: those leave the step.
  final AmountEntryState amount;

  const WithdrawAmount(this.open, this.amount);

  @override
  List<Object?> get _props => [open, amount];
}

/// Picking one of the user's own recipients on the market's rails.
/// [refused] is the last recipient picked that the filter does not admit.
final class WithdrawRecipient extends WithdrawFlowState {
  final WithdrawOpen open;
  final EnteredAmount amount;
  final Recipient? refused;

  const WithdrawRecipient(this.open, this.amount, {this.refused});

  RecipientFilter get filter => withdrawRecipientFilter(amount.market);

  @override
  List<Object?> get _props => [open, amount, refused];
}

/// Meeting the chosen recipient's payout requirements.
final class WithdrawRequirements extends WithdrawFlowState {
  final WithdrawOpen open;
  final EnteredAmount amount;
  final RequirementsRunning requirements;

  const WithdrawRequirements(this.open, this.amount, this.requirements);

  @override
  List<Object?> get _props => [open, amount, requirements];
}

/// Creating the withdrawal order through the write gate.
final class WithdrawOrdering extends WithdrawFlowState {
  final WithdrawOpen open;
  final EnteredAmount amount;
  final ReadyRecipient recipient;

  /// [OrderCreating], [OrderWriteRefused], [OrderCreateFailed],
  /// [OrderVerifying] or [OrderUnverified].
  final WithdrawOrderState order;

  const WithdrawOrdering(this.open, this.amount, this.recipient, this.order);

  @override
  List<Object?> get _props => [open, amount, recipient, order];
}

/// The created order, waiting for the user's Confirm.
final class WithdrawReview extends WithdrawFlowState {
  final WithdrawOpen open;
  final EnteredAmount amount;
  final ReadyRecipient recipient;
  final WithdrawOrder order;

  const WithdrawReview(this.open, this.amount, this.recipient, this.order);

  WithdrawConfirmTarget get target => WithdrawConfirmTarget(order, recipient);

  @override
  List<Object?> get _props => [open, amount, recipient, order.orderId];
}

/// Confirming the order: the money-moving write. Back here never re-offers
/// the write while its outcome may be unknown (WD-1, WD-2, WD-3).
final class WithdrawConfirming extends WithdrawFlowState {
  final WithdrawOpen open;
  final EnteredAmount amount;
  final ReadyRecipient recipient;
  final WithdrawOrder order;

  /// Never [ConfirmConfirmed], [ConfirmSessionEnded] or [ConfirmLeft].
  final WithdrawConfirmState confirm;

  const WithdrawConfirming(
    this.open,
    this.amount,
    this.recipient,
    this.order,
    this.confirm,
  );

  @override
  List<Object?> get _props => [open, amount, recipient, order.orderId, confirm];
}

/// The exchange confirmed the withdrawal.
final class WithdrawDone extends WithdrawFlowState {
  final WithdrawOpen open;
  final WithdrawOrder order;

  const WithdrawDone(this.open, this.order);

  @override
  List<Object?> get _props => [open, order.orderId];
}

/// The session the flow opened with ended. The only exit is Close.
final class WithdrawSessionEnded extends WithdrawFlowState {
  const WithdrawSessionEnded();

  @override
  List<Object?> get _props => const [];
}

/// The user left the flow.
final class WithdrawClosed extends WithdrawFlowState {
  const WithdrawClosed();

  @override
  List<Object?> get _props => const [];
}

@immutable
sealed class WithdrawFlowEvent {
  const WithdrawFlowEvent();
}

final class WithdrawContextLoaded extends WithdrawFlowEvent {
  final int attempt;
  final Result<WithdrawContext, ExchangeReadFailure> read;

  const WithdrawContextLoaded(this.attempt, this.read);
}

/// Retry of the account load.
final class WithdrawRetryPressed extends WithdrawFlowEvent {
  const WithdrawRetryPressed();
}

final class WithdrawAmountChanged extends WithdrawFlowEvent {
  final AmountEntryEvent event;

  const WithdrawAmountChanged(this.event);
}

final class WithdrawRecipientPicked extends WithdrawFlowEvent {
  final Recipient recipient;

  const WithdrawRecipientPicked(this.recipient);
}

final class WithdrawRequirementsChanged extends WithdrawFlowEvent {
  final RequirementsEvent event;

  const WithdrawRequirementsChanged(this.event);
}

final class WithdrawOrderChanged extends WithdrawFlowEvent {
  final WithdrawOrderEvent event;

  const WithdrawOrderChanged(this.event);
}

final class WithdrawConfirmPressed extends WithdrawFlowEvent {
  const WithdrawConfirmPressed();
}

final class WithdrawConfirmChanged extends WithdrawFlowEvent {
  final WithdrawConfirmEvent event;

  const WithdrawConfirmChanged(this.event);
}

/// App bar, system Back or a page the user removed.
final class WithdrawBackPressed extends WithdrawFlowEvent {
  const WithdrawBackPressed();
}

final class WithdrawDonePressed extends WithdrawFlowEvent {
  const WithdrawDonePressed();
}

/// The flow's screen became visible or hidden (route, app lifecycle).
final class WithdrawVisibilityChanged extends WithdrawFlowEvent {
  final bool visible;

  const WithdrawVisibilityChanged({required this.visible});
}

/// The signed-in session changed; null when signed out.
final class WithdrawSessionChanged extends WithdrawFlowEvent {
  final ExchangeSession? session;

  const WithdrawSessionChanged(this.session);
}

@immutable
sealed class WithdrawFlowEffect {
  const WithdrawFlowEffect();
}

final class WithdrawLoadContext extends WithdrawFlowEffect {
  final int attempt;

  const WithdrawLoadContext(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is WithdrawLoadContext && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(WithdrawLoadContext, attempt);
}

final class WithdrawFetchRate extends WithdrawFlowEffect {
  final Market market;

  const WithdrawFetchRate(this.market);

  @override
  bool operator ==(Object other) =>
      other is WithdrawFetchRate && other.market == market;

  @override
  int get hashCode => Object.hash(WithdrawFetchRate, market);
}

final class WithdrawRequirementsEffect extends WithdrawFlowEffect {
  final RequirementsEffect effect;

  const WithdrawRequirementsEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is WithdrawRequirementsEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(WithdrawRequirementsEffect, effect);
}

final class WithdrawOrderEffect extends WithdrawFlowEffect {
  final OrderStepEffect<WithdrawRequest> effect;

  const WithdrawOrderEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is WithdrawOrderEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(WithdrawOrderEffect, effect);
}

final class WithdrawConfirmEffect extends WithdrawFlowEffect {
  final ServerConfirmEffect<WithdrawConfirmTarget> effect;

  const WithdrawConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is WithdrawConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(WithdrawConfirmEffect, effect);
}

typedef WithdrawFlowNext = StepNext<WithdrawFlowState, WithdrawFlowEffect>;

const _ended = WithdrawFlowNext(WithdrawSessionEnded());
const _closed = WithdrawFlowNext(WithdrawClosed());

/// The flow for [session]; without a signed-in session it has ended.
WithdrawFlowNext withdrawFlowStart(ExchangeSession? session) =>
    switch (session) {
      final session? => WithdrawFlowNext(
        WithdrawLoading(session, const ContextLoading(1)),
        const [WithdrawLoadContext(1)],
      ),
      null => _ended,
    };

/// The re-read of a withdrawal whose confirm outcome is unknown: in progress
/// or completed means it was confirmed; awaiting confirmation or ended means
/// not; an unknown status can't tell.
ConfirmCheck<WithdrawOrder> withdrawConfirmCheck(
  Result<Order, ExchangeReadFailure> read,
) => switch (read) {
  Ok(value: final WithdrawOrder order) => switch (order.orderStatus) {
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
  Ok() => const ConfirmCheckFailed(ReadProblemMalformed()),
  Err(failure: ExchangeSessionRejectedFailure()) =>
    const ConfirmCheckSessionRejected(),
  Err(failure: ExchangeMissingFailure()) ||
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(
    failure: ExchangeMalformedFailure(),
  ) => ConfirmCheckFailed(ReadProblem.of(read)!),
};

ExchangeSession? _sessionOf(WithdrawFlowState state) => switch (state) {
  WithdrawLoading(:final session) => session,
  WithdrawAmount(:final open) ||
  WithdrawRecipient(:final open) ||
  WithdrawRequirements(:final open) ||
  WithdrawOrdering(:final open) ||
  WithdrawReview(:final open) ||
  WithdrawConfirming(:final open) ||
  WithdrawDone(:final open) => open.session,
  WithdrawSessionEnded() || WithdrawClosed() => null,
};

WithdrawFlowNext _loading(WithdrawLoading state, WithdrawFlowEvent event) {
  final ContextLoadEvent<WithdrawContext> loadEvent;
  switch (event) {
    case WithdrawContextLoaded(:final attempt, :final read):
      loadEvent = ContextLoaded(attempt, read);
    case WithdrawRetryPressed():
      loadEvent = const ContextRetryPressed();
    case WithdrawBackPressed() || WithdrawDonePressed():
      return _closed;
    case WithdrawAmountChanged() ||
        WithdrawRecipientPicked() ||
        WithdrawRequirementsChanged() ||
        WithdrawOrderChanged() ||
        WithdrawConfirmPressed() ||
        WithdrawConfirmChanged() ||
        WithdrawVisibilityChanged() ||
        WithdrawSessionChanged():
      return WithdrawFlowNext.stay(state);
  }
  final next = state.load.next(loadEvent);
  if (identical(next.state, state.load)) return WithdrawFlowNext.stay(state);
  return switch (next.state) {
    ContextReady(:final context) => _amountNext(
      WithdrawOpen(state.session, context),
      amountEntryStart(
        withdrawAmountPolicy,
        context.amountContext,
        preferred: context.preferredMarket,
      ),
    ),
    ContextSessionRejected() => _ended,
    ContextLoading() || ContextFailed() => WithdrawFlowNext(
      WithdrawLoading(state.session, next.state),
      [
        for (final effect in next.effects)
          switch (effect) {
            ContextFetch(:final attempt) => WithdrawLoadContext(attempt),
          },
      ],
    ),
  };
}

/// The flow after the amount step answered [next].
WithdrawFlowNext _amountNext(
  WithdrawOpen open,
  AmountEntryNext next,
) => switch (next.state) {
  AmountDone(:final amount) => WithdrawFlowNext(
    WithdrawRecipient(open, amount),
  ),
  AmountSessionRejected() => _ended,
  AmountNoMarket() ||
  AmountEditing() ||
  AmountKycDetour() ||
  AmountFundingDetour() => WithdrawFlowNext(WithdrawAmount(open, next.state), [
    for (final effect in next.effects)
      ...switch (effect) {
        AmountFetchRate(:final market) => [WithdrawFetchRate(market)],
        // The withdraw policy checks neither KYC nor offers funding.
        AmountOpenKyc() || AmountOpenFunding() => const <WithdrawFlowEffect>[],
      },
  ]),
};

WithdrawFlowNext _amount(WithdrawAmount state, WithdrawFlowEvent event) =>
    switch (event) {
      WithdrawAmountChanged(:final event) => _stepped(
        state,
        state.amount.next(withdrawAmountPolicy, event),
        state.amount,
        (next) => _amountNext(state.open, next),
      ),
      WithdrawBackPressed() => _closed,
      WithdrawContextLoaded() ||
      WithdrawRetryPressed() ||
      WithdrawRecipientPicked() ||
      WithdrawRequirementsChanged() ||
      WithdrawOrderChanged() ||
      WithdrawConfirmPressed() ||
      WithdrawConfirmChanged() ||
      WithdrawDonePressed() ||
      WithdrawVisibilityChanged() ||
      WithdrawSessionChanged() => WithdrawFlowNext.stay(state),
    };

/// A step's answer [next] to the flow: a stay of the step is a stay of the
/// flow (same instance, no effects).
WithdrawFlowNext _stepped<S, F>(
  WithdrawFlowState flow,
  StepNext<S, F> next,
  S current,
  WithdrawFlowNext Function(StepNext<S, F> next) map,
) => identical(next.state, current) && next.effects.isEmpty
    ? WithdrawFlowNext.stay(flow)
    : map(next);

/// The exchange refused [amount] for [limit]: back to the amount with the
/// draft, the limit known to the step from now on.
WithdrawFlowNext _amountRefused(
  WithdrawOpen open,
  EnteredAmount amount,
  ExchangeOrderLimit limit,
) {
  final learned = WithdrawOpen(
    open.session,
    open.context.withExchangeLimit(limit),
  );
  return _amountNext(
    learned,
    AmountDone(
      amount,
      learned.context.amountContext,
    ).next(withdrawAmountPolicy, AmountLimitRefused(limit)),
  );
}

/// Back to the amount with the entered draft kept.
WithdrawFlowNext _editAmount(WithdrawOpen open, EnteredAmount amount) =>
    _amountNext(
      open,
      AmountDone(
        amount,
        open.context.amountContext,
      ).next(withdrawAmountPolicy, const AmountEditRequested()),
    );

WithdrawFlowNext _recipient(WithdrawRecipient state, WithdrawFlowEvent event) =>
    switch (event) {
      WithdrawRecipientPicked(:final recipient) => switch (state.filter.choose(
        recipient,
      )) {
        final chosen? => _requirementsNext(
          state.open,
          state.amount,
          requirementsStart(
            withdrawRequirementsPolicy,
            chosen,
            PayoutPurpose.withdraw,
          ),
        ),
        null => WithdrawFlowNext(
          WithdrawRecipient(state.open, state.amount, refused: recipient),
        ),
      },
      WithdrawBackPressed() => _editAmount(state.open, state.amount),
      WithdrawContextLoaded() ||
      WithdrawRetryPressed() ||
      WithdrawAmountChanged() ||
      WithdrawRequirementsChanged() ||
      WithdrawOrderChanged() ||
      WithdrawConfirmPressed() ||
      WithdrawConfirmChanged() ||
      WithdrawDonePressed() ||
      WithdrawVisibilityChanged() ||
      WithdrawSessionChanged() => WithdrawFlowNext.stay(state),
    };

WithdrawFlowNext _requirementsNext(
  WithdrawOpen open,
  EnteredAmount amount,
  RequirementsNext next,
) => switch (next.state) {
  RequirementsReady(:final ready) => _order(
    open,
    amount,
    ready,
    orderCreateStart<WithdrawRequest, WithdrawOrder>(
      WithdrawRequest(amount, ready),
    ),
  ),
  RequirementsCancelled() => WithdrawFlowNext(WithdrawRecipient(open, amount)),
  RequirementsSessionEnded() => _ended,
  final RequirementsRunning running => WithdrawFlowNext(
    WithdrawRequirements(open, amount, running),
    [for (final effect in next.effects) WithdrawRequirementsEffect(effect)],
  ),
};

WithdrawFlowNext _requirements(
  WithdrawRequirements state,
  WithdrawFlowEvent event,
) {
  final RequirementsEvent stepEvent;
  switch (event) {
    case WithdrawRequirementsChanged(:final event):
      stepEvent = event;
    case WithdrawBackPressed():
      stepEvent = const RequirementsCancelPressed();
    case WithdrawVisibilityChanged(:final visible):
      final visibility = _visibility(state.requirements, visible);
      if (visibility == null) return WithdrawFlowNext.stay(state);
      stepEvent = visibility;
    case WithdrawContextLoaded() ||
        WithdrawRetryPressed() ||
        WithdrawAmountChanged() ||
        WithdrawRecipientPicked() ||
        WithdrawOrderChanged() ||
        WithdrawConfirmPressed() ||
        WithdrawConfirmChanged() ||
        WithdrawDonePressed() ||
        WithdrawSessionChanged():
      return WithdrawFlowNext.stay(state);
  }
  return _stepped(
    state,
    state.requirements.next(withdrawRequirementsPolicy, stepEvent),
    state.requirements,
    (next) => _requirementsNext(state.open, state.amount, next),
  );
}

/// The visibility event of the requirement being met, if it watches.
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

WithdrawFlowNext _order(
  WithdrawOpen open,
  EnteredAmount amount,
  ReadyRecipient recipient,
  OrderStepNext<WithdrawRequest, WithdrawOrder> next,
) => switch (next.state) {
  OrderPlaced(placed: QuotedOrder(:final order)) ||
  OrderQuoted(quoted: QuotedOrder(:final order)) ||
  OrderCommitted(
    quoted: QuotedOrder(:final order),
  ) => WithdrawFlowNext(WithdrawReview(open, amount, recipient, order)),
  OrderLeft() => WithdrawFlowNext(WithdrawRecipient(open, amount)),
  // Retry would send the same amount: back to it, with the limit shown.
  OrderAmountRefused(:final limit) => _amountRefused(open, amount, limit),
  OrderSessionEnded() => _ended,
  OrderCreating() ||
  OrderWriteRefused() ||
  OrderCreateFailed() ||
  OrderVerifying() ||
  OrderUnverified() => WithdrawFlowNext(
    WithdrawOrdering(open, amount, recipient, next.state),
    [for (final effect in next.effects) WithdrawOrderEffect(effect)],
  ),
};

WithdrawFlowNext _ordering(WithdrawOrdering state, WithdrawFlowEvent event) {
  final WithdrawOrderEvent stepEvent;
  switch (event) {
    case WithdrawOrderChanged(:final event):
      stepEvent = event;
    case WithdrawRetryPressed():
      stepEvent = const OrderRetryPressed();
    case WithdrawBackPressed():
      stepEvent = const OrderBackPressed();
    case WithdrawContextLoaded() ||
        WithdrawAmountChanged() ||
        WithdrawRecipientPicked() ||
        WithdrawRequirementsChanged() ||
        WithdrawConfirmPressed() ||
        WithdrawConfirmChanged() ||
        WithdrawDonePressed() ||
        WithdrawVisibilityChanged() ||
        WithdrawSessionChanged():
      return WithdrawFlowNext.stay(state);
  }
  return _stepped(
    state,
    state.order.next(withdrawOrderPolicy, stepEvent),
    state.order,
    (next) => _order(state.open, state.amount, state.recipient, next),
  );
}

WithdrawFlowNext _review(WithdrawReview state, WithdrawFlowEvent event) =>
    switch (event) {
      WithdrawConfirmPressed() => _confirm(
        state.open,
        state.amount,
        state.recipient,
        state.order,
        serverConfirmStart<WithdrawConfirmTarget, WithdrawOrder>(
          state.target,
          openEntry: openEntryFor(
            withdrawConfirmPolicy,
            state.target,
            state.open.context.openEntries,
          ),
        ),
      ),
      WithdrawBackPressed() => WithdrawFlowNext(
        WithdrawRecipient(state.open, state.amount),
      ),
      WithdrawContextLoaded() ||
      WithdrawRetryPressed() ||
      WithdrawAmountChanged() ||
      WithdrawRecipientPicked() ||
      WithdrawRequirementsChanged() ||
      WithdrawOrderChanged() ||
      WithdrawConfirmChanged() ||
      WithdrawDonePressed() ||
      WithdrawVisibilityChanged() ||
      WithdrawSessionChanged() => WithdrawFlowNext.stay(state),
    };

WithdrawFlowNext _confirm(
  WithdrawOpen open,
  EnteredAmount amount,
  ReadyRecipient recipient,
  WithdrawOrder order,
  ServerConfirmNext<WithdrawConfirmTarget, WithdrawOrder> next,
) => switch (next.state) {
  ConfirmConfirmed(:final confirmed) => WithdrawFlowNext(
    WithdrawDone(open, confirmed),
  ),
  ConfirmSessionEnded() => _ended,
  // Leaving a failed, refused or unverified confirm ends the flow: going
  // back to the recipients could create a second withdrawal while the
  // first may have gone through.
  ConfirmLeft() => _closed,
  ConfirmConfirming() ||
  ConfirmWriteRefused() ||
  ConfirmFailed() ||
  ConfirmVerifying() ||
  ConfirmUnverified() => WithdrawFlowNext(
    WithdrawConfirming(open, amount, recipient, order, next.state),
    [for (final effect in next.effects) WithdrawConfirmEffect(effect)],
  ),
};

WithdrawFlowNext _confirming(
  WithdrawConfirming state,
  WithdrawFlowEvent event,
) {
  final WithdrawConfirmEvent stepEvent;
  switch (event) {
    case WithdrawConfirmChanged(:final event):
      stepEvent = event;
    case WithdrawConfirmPressed() || WithdrawRetryPressed():
      stepEvent = const ConfirmRetryPressed();
    case WithdrawBackPressed():
      stepEvent = const ConfirmBackPressed();
    case WithdrawContextLoaded() ||
        WithdrawAmountChanged() ||
        WithdrawRecipientPicked() ||
        WithdrawRequirementsChanged() ||
        WithdrawOrderChanged() ||
        WithdrawDonePressed() ||
        WithdrawVisibilityChanged() ||
        WithdrawSessionChanged():
      return WithdrawFlowNext.stay(state);
  }
  return _stepped(
    state,
    state.confirm.next(withdrawConfirmPolicy, stepEvent),
    state.confirm,
    (next) =>
        _confirm(state.open, state.amount, state.recipient, state.order, next),
  );
}

WithdrawFlowNext _done(WithdrawDone state, WithdrawFlowEvent event) =>
    switch (event) {
      WithdrawDonePressed() || WithdrawBackPressed() => _closed,
      WithdrawContextLoaded() ||
      WithdrawRetryPressed() ||
      WithdrawAmountChanged() ||
      WithdrawRecipientPicked() ||
      WithdrawRequirementsChanged() ||
      WithdrawOrderChanged() ||
      WithdrawConfirmPressed() ||
      WithdrawConfirmChanged() ||
      WithdrawVisibilityChanged() ||
      WithdrawSessionChanged() => WithdrawFlowNext.stay(state),
    };

WithdrawFlowNext _sessionEnded(
  WithdrawSessionEnded state,
  WithdrawFlowEvent event,
) => switch (event) {
  WithdrawDonePressed() || WithdrawBackPressed() => _closed,
  WithdrawContextLoaded() ||
  WithdrawRetryPressed() ||
  WithdrawAmountChanged() ||
  WithdrawRecipientPicked() ||
  WithdrawRequirementsChanged() ||
  WithdrawOrderChanged() ||
  WithdrawConfirmPressed() ||
  WithdrawConfirmChanged() ||
  WithdrawVisibilityChanged() ||
  WithdrawSessionChanged() => WithdrawFlowNext.stay(state),
};

bool _sameLimits(
  Map<FiatCurrency, AmountLimits> a,
  Map<FiatCurrency, AmountLimits> b,
) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
