import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Accelerating a confirmed buy's bitcoin payout (composition §5, buy's
/// add-on): load the order and what the express payout costs → Confirm
/// express (a server confirm through the write gate) → done. Opened by order
/// id, from the buy's done page or from the transaction details.
@immutable
sealed class AccelerateFlowState {
  const AccelerateFlowState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is AccelerateFlowState &&
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

/// What the express payout costs: the network fee rate, the fee of a
/// typical payout in sats, and the fiat price of a bitcoin in the order's
/// currency.
@immutable
final class AccelerateFee {
  final double satPerVbyte;
  final int sats;
  final double fiatPerBitcoin;

  const AccelerateFee({
    required this.satPerVbyte,
    required this.sats,
    required this.fiatPerBitcoin,
  });

  @override
  bool operator ==(Object other) =>
      other is AccelerateFee &&
      other.satPerVbyte == satPerVbyte &&
      other.sats == sats &&
      other.fiatPerBitcoin == fiatPerBitcoin;

  @override
  int get hashCode => Object.hash(satPerVbyte, sats, fiatPerBitcoin);
}

/// The one load of the flow: the order, its fee, and the open journal
/// entries (an accelerate whose outcome is unknown starts in Verifying).
@immutable
final class AccelerateQuote {
  final BuyOrder order;
  final AccelerateFee fee;
  final List<UnknownWrite> openEntries;

  const AccelerateQuote(this.order, this.fee, this.openEntries);

  AccelerateTarget get target => AccelerateTarget(order.orderId);

  @override
  bool operator ==(Object other) =>
      other is AccelerateQuote &&
      other.order == order &&
      other.fee == fee &&
      identical(other.openEntries, openEntries);

  @override
  int get hashCode => Object.hash(order, fee, openEntries.length);
}

@immutable
final class AccelerateTarget {
  final String orderId;

  const AccelerateTarget(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is AccelerateTarget && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(AccelerateTarget, orderId);
}

String _targetId(AccelerateTarget target) => target.orderId;

const accelerateConfirmPolicy = ServerConfirmPolicy<AccelerateTarget>(
  writeKind: FinancialWriteKind.accelerate,
  journalKind: UnknownWriteKind.accelerate,
  resourceIdOf: _targetId,
);

/// The re-read after an accelerate whose outcome is unknown: an order
/// whose payout was unbatched, sent or completed was accelerated. Anything
/// else can't tell (the express payout may not show yet), so the flow
/// checks again and never sends the accelerate twice.
ConfirmCheck<BuyOrder> accelerateConfirmCheck(
  Result<Order, ExchangeReadFailure> read,
) => switch (read) {
  Ok(value: final BuyOrder order)
      when order.unbatchedBuyOnchainFees != null ||
          order.transactionId != null ||
          order.payoutStatus == OrderPayoutStatus.completed =>
    ConfirmSeenApplied(order),
  Ok() => const ConfirmCheckFailed(ReadProblemMissing()),
  Err(failure: ExchangeSessionRejectedFailure()) =>
    const ConfirmCheckSessionRejected(),
  Err(failure: ExchangeMissingFailure()) ||
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(
    failure: ExchangeMalformedFailure(),
  ) => ConfirmCheckFailed(ReadProblem.of(read)!),
};

typedef AccelerateConfirmState = ServerConfirmState<AccelerateTarget, BuyOrder>;
typedef AccelerateConfirmEvent = ServerConfirmEvent<AccelerateTarget, BuyOrder>;

final class AccelerateLoading extends AccelerateFlowState {
  final ExchangeSession session;
  final String orderId;

  /// [ContextLoading] or [ContextFailed].
  final ContextLoadState<AccelerateQuote> load;

  const AccelerateLoading(this.session, this.orderId, this.load);

  @override
  List<Object?> get _props => [session, orderId, load];
}

/// The order and its fee, waiting for Confirm express or Wait.
final class AccelerateReady extends AccelerateFlowState {
  final ExchangeSession session;
  final AccelerateQuote quote;

  const AccelerateReady(this.session, this.quote);

  @override
  List<Object?> get _props => [session, quote];
}

final class AccelerateConfirming extends AccelerateFlowState {
  final ExchangeSession session;
  final AccelerateQuote quote;

  /// Never [ConfirmConfirmed], [ConfirmSessionEnded] or [ConfirmLeft].
  final AccelerateConfirmState confirm;

  const AccelerateConfirming(this.session, this.quote, this.confirm);

  @override
  List<Object?> get _props => [session, quote, confirm];
}

/// The exchange sends the payout now.
final class AccelerateDone extends AccelerateFlowState {
  final ExchangeSession session;
  final BuyOrder order;

  const AccelerateDone(this.session, this.order);

  @override
  List<Object?> get _props => [session, order.orderId];
}

final class AccelerateSessionEnded extends AccelerateFlowState {
  const AccelerateSessionEnded();

  @override
  List<Object?> get _props => const [];
}

final class AccelerateClosed extends AccelerateFlowState {
  const AccelerateClosed();

  @override
  List<Object?> get _props => const [];
}

@immutable
sealed class AccelerateFlowEvent {
  const AccelerateFlowEvent();
}

final class AccelerateLoaded extends AccelerateFlowEvent {
  final int attempt;
  final Result<AccelerateQuote, ExchangeReadFailure> read;

  const AccelerateLoaded(this.attempt, this.read);
}

final class AccelerateRetryPressed extends AccelerateFlowEvent {
  const AccelerateRetryPressed();
}

final class AccelerateConfirmPressed extends AccelerateFlowEvent {
  const AccelerateConfirmPressed();
}

final class AccelerateConfirmChanged extends AccelerateFlowEvent {
  final AccelerateConfirmEvent event;

  const AccelerateConfirmChanged(this.event);
}

/// Back, or "Wait for free withdrawal".
final class AccelerateBackPressed extends AccelerateFlowEvent {
  const AccelerateBackPressed();
}

final class AccelerateDonePressed extends AccelerateFlowEvent {
  const AccelerateDonePressed();
}

final class AccelerateSessionChanged extends AccelerateFlowEvent {
  final ExchangeSession? session;

  const AccelerateSessionChanged(this.session);
}

@immutable
sealed class AccelerateFlowEffect {
  const AccelerateFlowEffect();
}

final class AccelerateLoad extends AccelerateFlowEffect {
  final String orderId;
  final int attempt;

  const AccelerateLoad(this.orderId, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is AccelerateLoad &&
      other.orderId == orderId &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(AccelerateLoad, orderId, attempt);
}

final class AccelerateConfirmEffect extends AccelerateFlowEffect {
  final ServerConfirmEffect<AccelerateTarget> effect;

  const AccelerateConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is AccelerateConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(AccelerateConfirmEffect, effect);
}

typedef AccelerateFlowNext =
    StepNext<AccelerateFlowState, AccelerateFlowEffect>;

const _ended = AccelerateFlowNext(AccelerateSessionEnded());
const _closed = AccelerateFlowNext(AccelerateClosed());

AccelerateFlowNext accelerateFlowStart(
  ExchangeSession? session,
  String orderId,
) => switch (session) {
  final session? => AccelerateFlowNext(
    AccelerateLoading(session, orderId, const ContextLoading(1)),
    [AccelerateLoad(orderId, 1)],
  ),
  null => _ended,
};

AccelerateFlowNext transitionAccelerateFlow(
  AccelerateFlowState state,
  AccelerateFlowEvent event,
) {
  if (event case AccelerateSessionChanged(:final session)) {
    final current = switch (state) {
      AccelerateLoading(:final session) ||
      AccelerateReady(:final session) ||
      AccelerateConfirming(:final session) ||
      AccelerateDone(:final session) => session,
      AccelerateSessionEnded() || AccelerateClosed() => null,
    };
    return current != null && current != session
        ? _ended
        : AccelerateFlowNext.stay(state);
  }
  return switch (state) {
    AccelerateLoading() => _loading(state, event),
    AccelerateReady() => _ready(state, event),
    AccelerateConfirming() => _confirming(state, event),
    AccelerateDone() || AccelerateSessionEnded() => switch (event) {
      AccelerateBackPressed() || AccelerateDonePressed() => _closed,
      AccelerateLoaded() ||
      AccelerateRetryPressed() ||
      AccelerateConfirmPressed() ||
      AccelerateConfirmChanged() ||
      AccelerateSessionChanged() => AccelerateFlowNext.stay(state),
    },
    AccelerateClosed() => AccelerateFlowNext.stay(state),
  };
}

AccelerateFlowNext _loading(
  AccelerateLoading state,
  AccelerateFlowEvent event,
) {
  final ContextLoadEvent<AccelerateQuote> loadEvent;
  switch (event) {
    case AccelerateLoaded(:final attempt, :final read):
      loadEvent = ContextLoaded(attempt, read);
    case AccelerateRetryPressed():
      loadEvent = const ContextRetryPressed();
    case AccelerateBackPressed() || AccelerateDonePressed():
      return _closed;
    case AccelerateConfirmPressed() ||
        AccelerateConfirmChanged() ||
        AccelerateSessionChanged():
      return AccelerateFlowNext.stay(state);
  }
  final next = transitionContextLoad(state.load, loadEvent);
  if (identical(next.state, state.load)) {
    return AccelerateFlowNext.stay(state);
  }
  return switch (next.state) {
    ContextReady(:final context) => AccelerateFlowNext(
      AccelerateReady(state.session, context),
    ),
    ContextSessionRejected() => _ended,
    ContextLoading() || ContextFailed() => AccelerateFlowNext(
      AccelerateLoading(state.session, state.orderId, next.state),
      [
        for (final effect in next.effects)
          switch (effect) {
            ContextFetch(:final attempt) => AccelerateLoad(
              state.orderId,
              attempt,
            ),
          },
      ],
    ),
  };
}

AccelerateFlowNext _ready(AccelerateReady state, AccelerateFlowEvent event) =>
    switch (event) {
      AccelerateConfirmPressed() => _confirmNext(
        state.session,
        state.quote,
        serverConfirmStart<AccelerateTarget, BuyOrder>(
          state.quote.target,
          openEntry: openEntryFor(
            accelerateConfirmPolicy,
            state.quote.target,
            state.quote.openEntries,
          ),
        ),
      ),
      AccelerateBackPressed() || AccelerateDonePressed() => _closed,
      AccelerateLoaded() ||
      AccelerateRetryPressed() ||
      AccelerateConfirmChanged() ||
      AccelerateSessionChanged() => AccelerateFlowNext.stay(state),
    };

AccelerateFlowNext _confirmNext(
  ExchangeSession session,
  AccelerateQuote quote,
  ServerConfirmNext<AccelerateTarget, BuyOrder> next,
) => switch (next.state) {
  ConfirmConfirmed(:final confirmed) => AccelerateFlowNext(
    AccelerateDone(session, confirmed),
  ),
  ConfirmSessionEnded() => _ended,
  // Back from a refused or failed accelerate: nothing took effect.
  ConfirmLeft() => AccelerateFlowNext(AccelerateReady(session, quote)),
  ConfirmConfirming() ||
  ConfirmWriteRefused() ||
  ConfirmFailed() ||
  ConfirmVerifying() ||
  ConfirmUnverified() => AccelerateFlowNext(
    AccelerateConfirming(session, quote, next.state),
    [for (final effect in next.effects) AccelerateConfirmEffect(effect)],
  ),
};

AccelerateFlowNext _confirming(
  AccelerateConfirming state,
  AccelerateFlowEvent event,
) {
  final AccelerateConfirmEvent stepEvent;
  switch (event) {
    case AccelerateConfirmChanged(:final event):
      stepEvent = event;
    case AccelerateConfirmPressed():
      stepEvent = const ConfirmCommitPressed();
    case AccelerateRetryPressed():
      stepEvent = const ConfirmRetryPressed();
    case AccelerateBackPressed():
      // An unverified accelerate may have gone through: leave, never back
      // to Confirm.
      if (state.confirm is ConfirmUnverified) return _closed;
      stepEvent = const ConfirmBackPressed();
    case AccelerateLoaded() ||
        AccelerateDonePressed() ||
        AccelerateSessionChanged():
      return AccelerateFlowNext.stay(state);
  }
  final next = transitionServerConfirm(
    accelerateConfirmPolicy,
    state.confirm,
    stepEvent,
  );
  if (identical(next.state, state.confirm) && next.effects.isEmpty) {
    return AccelerateFlowNext.stay(state);
  }
  return _confirmNext(state.session, state.quote, next);
}
