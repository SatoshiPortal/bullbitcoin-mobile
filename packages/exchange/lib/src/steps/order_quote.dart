import 'package:meta/meta.dart';

import '../domain/exchange_access.dart';
import '../domain/exchange_call_result.dart';
import '../domain/exchange_failure.dart';
import '../domain/exchange_write_gate.dart';
import 'step_next.dart';

/// An order with the id its replies are keyed by.
@immutable
final class QuotedOrder<O> {
  final String id;
  final O order;

  const QuotedOrder(this.id, this.order);

  @override
  bool operator ==(Object other) =>
      other is QuotedOrder && other.id == id && other.order == order;

  @override
  int get hashCode => Object.hash(QuotedOrder, id, order);

  @override
  String toString() => 'QuotedOrder($id)';
}

@immutable
final class OrderPolicy<O> {
  final String Function(O order) idOf;

  /// The order has a price lock that is refreshed when it falls due.
  final bool locks;

  /// Failed refreshes in a row before the quote is unavailable.
  final int maxRefreshRetries;

  const OrderPolicy({
    required this.idOf,
    required this.locks,
    this.maxRefreshRetries = 3,
  });
}

/// The state of a held quote.
@immutable
sealed class QuoteStatus {
  const QuoteStatus();
}

final class QuoteLive extends QuoteStatus {
  const QuoteLive();
}

/// A refresh is in flight after [failures] failed ones in a row.
final class QuoteRefreshing extends QuoteStatus {
  final int failures;

  const QuoteRefreshing(this.failures);

  @override
  bool operator ==(Object other) =>
      other is QuoteRefreshing && other.failures == failures;

  @override
  int get hashCode => Object.hash(QuoteRefreshing, failures);

  @override
  String toString() => 'QuoteRefreshing($failures)';
}

/// [failures] refreshes failed in a row; the next one is scheduled.
final class QuoteRetrying extends QuoteStatus {
  final int failures;

  const QuoteRetrying(this.failures);

  @override
  bool operator ==(Object other) =>
      other is QuoteRetrying && other.failures == failures;

  @override
  int get hashCode => Object.hash(QuoteRetrying, failures);

  @override
  String toString() => 'QuoteRetrying($failures)';
}

/// The quote could not be refreshed; Retry refreshes again, Commit is off.
final class QuoteUnavailable extends QuoteStatus {
  const QuoteUnavailable();
}

/// Creating an order and keeping its quote (composition §4.7). [R] is the
/// flow's create request (built from the earlier steps' outputs), [O] its
/// order. The output is [OrderCommitted] (a [QuotedOrder] the user committed
/// to) or, for flows without a price lock, [OrderPlaced].
@immutable
sealed class OrderStepState<R, O> {
  const OrderStepState();
}

/// The create of [attempt] is in flight. Back is a stay.
final class OrderCreating<R, O> extends OrderStepState<R, O> {
  final R request;
  final int attempt;

  const OrderCreating(this.request, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is OrderCreating &&
      other.request == request &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(OrderCreating, request, attempt);

  @override
  String toString() => 'OrderCreating($request, $attempt)';
}

/// The account's write gate refused the create; nothing was sent.
final class OrderWriteRefused<R, O> extends OrderStepState<R, O> {
  final R request;
  final int attempt;
  final WriteGateRefusal refusal;

  const OrderWriteRefused(this.request, this.attempt, this.refusal);

  @override
  bool operator ==(Object other) =>
      other is OrderWriteRefused &&
      other.request == request &&
      other.attempt == attempt &&
      other.refusal == refusal;

  @override
  int get hashCode => Object.hash(OrderWriteRefused, request, attempt, refusal);

  @override
  String toString() => 'OrderWriteRefused($request, $attempt, $refusal)';
}

/// The create did not take effect; it may be sent again.
final class OrderCreateFailed<R, O> extends OrderStepState<R, O> {
  final R request;
  final int attempt;
  final WriteProblem problem;

  const OrderCreateFailed(this.request, this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is OrderCreateFailed &&
      other.request == request &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(OrderCreateFailed, request, attempt, problem);

  @override
  String toString() => 'OrderCreateFailed($request, $attempt, $problem)';
}

/// The create may have reached the exchange: recent orders are read and
/// matched to [request]. The create is never sent again from here.
final class OrderVerifying<R, O> extends OrderStepState<R, O> {
  final R request;
  final int attempt;

  const OrderVerifying(this.request, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is OrderVerifying &&
      other.request == request &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(OrderVerifying, request, attempt);

  @override
  String toString() => 'OrderVerifying($request, $attempt)';
}

/// The re-read failed or found no matching order; Retry reads again (never
/// creates again).
final class OrderUnverified<R, O> extends OrderStepState<R, O> {
  final R request;
  final int attempt;
  final ReadProblem problem;

  const OrderUnverified(this.request, this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is OrderUnverified &&
      other.request == request &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(OrderUnverified, request, attempt, problem);

  @override
  String toString() => 'OrderUnverified($request, $attempt, $problem)';
}

final class OrderQuoted<R, O> extends OrderStepState<R, O> {
  final QuotedOrder<O> quoted;
  final QuoteStatus status;

  const OrderQuoted(this.quoted, this.status);

  @override
  bool operator ==(Object other) =>
      other is OrderQuoted && other.quoted == quoted && other.status == status;

  @override
  int get hashCode => Object.hash(OrderQuoted, quoted, status);

  @override
  String toString() => 'OrderQuoted($quoted, $status)';
}

/// Output for flows without a lock.
final class OrderPlaced<R, O> extends OrderStepState<R, O> {
  final QuotedOrder<O> placed;

  const OrderPlaced(this.placed);

  @override
  bool operator ==(Object other) =>
      other is OrderPlaced && other.placed == placed;

  @override
  int get hashCode => Object.hash(OrderPlaced, placed);

  @override
  String toString() => 'OrderPlaced($placed)';
}

/// Output: the user committed to a live quote; the commit step takes it.
final class OrderCommitted<R, O> extends OrderStepState<R, O> {
  final QuotedOrder<O> quoted;

  const OrderCommitted(this.quoted);

  @override
  bool operator ==(Object other) =>
      other is OrderCommitted && other.quoted == quoted;

  @override
  int get hashCode => Object.hash(OrderCommitted, quoted);

  @override
  String toString() => 'OrderCommitted($quoted)';
}

/// A call got HTTP 401: the flow ends its session. Terminal.
final class OrderSessionEnded<R, O> extends OrderStepState<R, O> {
  const OrderSessionEnded();

  @override
  bool operator ==(Object other) => other is OrderSessionEnded;

  @override
  int get hashCode => (OrderSessionEnded).hashCode;
}

/// The exchange refused the order for its amount: [limit] is the bound it
/// broke. Terminal: the flow takes the user back to the amount step with
/// the limit (Retry would send the same amount and fail the same way).
final class OrderAmountRefused<R, O> extends OrderStepState<R, O> {
  final R request;
  final ExchangeOrderLimit limit;

  const OrderAmountRefused(this.request, this.limit);

  @override
  bool operator ==(Object other) =>
      other is OrderAmountRefused &&
      other.request == request &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(OrderAmountRefused, request, limit);

  @override
  String toString() => 'OrderAmountRefused($request, $limit)';
}

/// The user went back to the previous step. Terminal.
final class OrderLeft<R, O> extends OrderStepState<R, O> {
  const OrderLeft();

  @override
  bool operator ==(Object other) => other is OrderLeft;

  @override
  int get hashCode => (OrderLeft).hashCode;
}

@immutable
sealed class OrderStepEvent<R, O> {
  const OrderStepEvent();
}

/// What the write gate and the create of [attempt] answered.
final class OrderCreateAnswered<R, O> extends OrderStepEvent<R, O> {
  final int attempt;
  final GatedWrite<ExchangeWrite<O>> answer;

  const OrderCreateAnswered(this.attempt, this.answer);
}

/// The re-read after an unknown create of [attempt]: [ReadGot] is the
/// matching order, [ReadMissing] means no order matched, which cannot prove
/// the create did not happen.
final class OrderFindAnswered<R, O> extends OrderStepEvent<R, O> {
  final int attempt;
  final ExchangeRead<O> read;

  const OrderFindAnswered(this.attempt, this.read);
}

final class OrderLockDue<R, O> extends OrderStepEvent<R, O> {
  final String orderId;

  const OrderLockDue(this.orderId);
}

final class OrderRefreshed<R, O> extends OrderStepEvent<R, O> {
  final String orderId;
  final ExchangeRead<O> read;

  const OrderRefreshed(this.orderId, this.read);
}

final class OrderRetryDue<R, O> extends OrderStepEvent<R, O> {
  final String orderId;

  const OrderRetryDue(this.orderId);
}

final class OrderRetryPressed<R, O> extends OrderStepEvent<R, O> {
  const OrderRetryPressed();
}

final class OrderCommitPressed<R, O> extends OrderStepEvent<R, O> {
  const OrderCommitPressed();
}

final class OrderBackPressed<R, O> extends OrderStepEvent<R, O> {
  const OrderBackPressed();
}

@immutable
sealed class OrderStepEffect<R> {
  const OrderStepEffect();
}

/// Send the create through the account's write gate ([runOrderCreate]);
/// answer [OrderCreateAnswered] for [attempt].
final class OrderSendCreate<R> extends OrderStepEffect<R> {
  final R request;
  final int attempt;

  const OrderSendCreate(this.request, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is OrderSendCreate &&
      other.request == request &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(OrderSendCreate, request, attempt);

  @override
  String toString() => 'OrderSendCreate($request, $attempt)';
}

/// Read recent orders and match [request]; answer [OrderFindAnswered].
final class OrderFindCreated<R> extends OrderStepEffect<R> {
  final R request;
  final int attempt;

  const OrderFindCreated(this.request, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is OrderFindCreated &&
      other.request == request &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(OrderFindCreated, request, attempt);

  @override
  String toString() => 'OrderFindCreated($request, $attempt)';
}

/// Arm the lock timer of [orderId] from the order's expiry; answer
/// [OrderLockDue].
final class OrderStartLockTimer<R> extends OrderStepEffect<R> {
  final String orderId;

  const OrderStartLockTimer(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is OrderStartLockTimer && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(OrderStartLockTimer, orderId);

  @override
  String toString() => 'OrderStartLockTimer($orderId)';
}

/// Read [orderId] again; answer [OrderRefreshed].
final class OrderRefresh<R> extends OrderStepEffect<R> {
  final String orderId;

  const OrderRefresh(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is OrderRefresh && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(OrderRefresh, orderId);

  @override
  String toString() => 'OrderRefresh($orderId)';
}

/// Wait before refresh number [failures] + 1; answer [OrderRetryDue].
final class OrderScheduleRefreshRetry<R> extends OrderStepEffect<R> {
  final String orderId;
  final int failures;

  const OrderScheduleRefreshRetry(this.orderId, this.failures);

  @override
  bool operator ==(Object other) =>
      other is OrderScheduleRefreshRetry &&
      other.orderId == orderId &&
      other.failures == failures;

  @override
  int get hashCode => Object.hash(OrderScheduleRefreshRetry, orderId, failures);

  @override
  String toString() => 'OrderScheduleRefreshRetry($orderId, $failures)';
}

/// Cancel the lock and retry timers of [orderId].
final class OrderStopTimers<R> extends OrderStepEffect<R> {
  final String orderId;

  const OrderStopTimers(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is OrderStopTimers && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(OrderStopTimers, orderId);

  @override
  String toString() => 'OrderStopTimers($orderId)';
}

/// The user left a held order: release what it holds (a payjoin receiver).
final class OrderRelease<R> extends OrderStepEffect<R> {
  final String orderId;

  const OrderRelease(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is OrderRelease && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(OrderRelease, orderId);

  @override
  String toString() => 'OrderRelease($orderId)';
}

typedef OrderStepNext<R, O> =
    StepNext<OrderStepState<R, O>, OrderStepEffect<R>>;

OrderStepNext<R, O> orderCreateStart<R, O>(R request) =>
    StepNext(OrderCreating<R, O>(request, 1), [OrderSendCreate(request, 1)]);

/// Runs [OrderSendCreate] through [gate] for [session]'s account. An unknown
/// outcome is handed to [journalUnknown] (`Exchange.journalUnknownOrderCreate`)
/// before the answer moves the step to Verifying, so reconcile can still
/// find the order if the flow is left.
Future<OrderCreateAnswered<R, O>> runOrderCreate<R, O>({
  required ExchangeWriteGate gate,
  required ExchangeSession session,
  required OrderSendCreate<R> effect,
  required Future<ExchangeWrite<O>> Function(R request) create,
  required Future<void> Function(R request) journalUnknown,
}) async {
  final answer = await gate.run(
    session,
    FinancialWriteKind.orderCreate,
    () => create(effect.request),
  );
  if (answer case GateAdmitted(result: WriteOutcomeUnknown())) {
    await journalUnknown(effect.request);
  }
  return OrderCreateAnswered(effect.attempt, answer);
}

OrderStepNext<R, O> _held<R, O>(OrderPolicy<O> policy, O order) {
  final quoted = QuotedOrder(policy.idOf(order), order);
  return policy.locks
      ? StepNext(OrderQuoted<R, O>(quoted, const QuoteLive()), [
          OrderStartLockTimer(quoted.id),
        ])
      : StepNext(OrderPlaced<R, O>(quoted));
}

OrderStepNext<R, O> _created<R, O>(
  OrderPolicy<O> policy,
  R request,
  int attempt,
  GatedWrite<ExchangeWrite<O>> answer,
) => switch (answer) {
  GateRefused(:final refusal) => StepNext(
    OrderWriteRefused<R, O>(request, attempt, refusal),
  ),
  GateAdmitted(result: WriteDone(:final value)) => _held(policy, value),
  GateAdmitted(
    result: WriteRefused(reason: ExchangeRefusal(orderLimit: final limit?)),
  ) =>
    StepNext(OrderAmountRefused<R, O>(request, limit)),
  GateAdmitted(result: WriteRefused(:final reason)) => StepNext(
    OrderCreateFailed<R, O>(request, attempt, WriteProblemRefused(reason)),
  ),
  GateAdmitted(result: WriteNotSent(:final reason)) => StepNext(
    OrderCreateFailed<R, O>(request, attempt, WriteProblemNotSent(reason)),
  ),
  GateAdmitted(result: WriteOutcomeUnknown()) => StepNext(
    OrderVerifying<R, O>(request, attempt),
    [OrderFindCreated(request, attempt)],
  ),
  GateAdmitted(result: WriteSessionRejected()) => StepNext(
    OrderSessionEnded<R, O>(),
  ),
};

OrderStepNext<R, O> _found<R, O>(
  OrderPolicy<O> policy,
  R request,
  int attempt,
  ExchangeRead<O> read,
) => switch (read) {
  ReadGot(:final value) => _held(policy, value),
  ReadMissing() => StepNext(
    OrderUnverified<R, O>(request, attempt, const ReadProblemMissing()),
  ),
  ReadUnreachable() || ReadMalformed() => StepNext(
    OrderUnverified<R, O>(request, attempt, ReadProblem.of(read)!),
  ),
  ReadSessionRejected() => StepNext(OrderSessionEnded<R, O>()),
};

OrderStepNext<R, O> _refreshed<R, O>(
  OrderPolicy<O> policy,
  QuotedOrder<O> quoted,
  int failures,
  ExchangeRead<O> read,
) => switch (read) {
  ReadGot(:final value) => StepNext(
    OrderQuoted<R, O>(QuotedOrder(quoted.id, value), const QuoteLive()),
    [OrderStartLockTimer(quoted.id)],
  ),
  ReadSessionRejected() => StepNext(OrderSessionEnded<R, O>(), [
    OrderStopTimers(quoted.id),
  ]),
  ReadMissing() || ReadUnreachable() || ReadMalformed() =>
    failures + 1 > policy.maxRefreshRetries
        ? StepNext(OrderQuoted<R, O>(quoted, const QuoteUnavailable()))
        : StepNext(OrderQuoted<R, O>(quoted, QuoteRetrying(failures + 1)), [
            OrderScheduleRefreshRetry(quoted.id, failures + 1),
          ]),
};

OrderStepNext<R, O> transitionOrderStep<R, O>(
  OrderPolicy<O> policy,
  OrderStepState<R, O> state,
  OrderStepEvent<R, O> event,
) => switch ((state, event)) {
  (
    OrderCreating(:final request, :final attempt),
    OrderCreateAnswered(attempt: final answered, :final answer),
  )
      when answered == attempt =>
    _created(policy, request, attempt, answer),
  (
    OrderCreating(),
    OrderCreateAnswered() ||
        OrderFindAnswered() ||
        OrderLockDue() ||
        OrderRefreshed() ||
        OrderRetryDue() ||
        OrderRetryPressed() ||
        OrderCommitPressed() ||
        OrderBackPressed(),
  ) =>
    StepNext.stay(state),

  (
    OrderWriteRefused(:final request, :final attempt) ||
        OrderCreateFailed(:final request, :final attempt),
    OrderRetryPressed(),
  ) =>
    StepNext(OrderCreating<R, O>(request, attempt + 1), [
      OrderSendCreate(request, attempt + 1),
    ]),
  (
    OrderWriteRefused() || OrderCreateFailed() || OrderUnverified(),
    OrderBackPressed(),
  ) =>
    StepNext(OrderLeft<R, O>()),
  (
    OrderWriteRefused() || OrderCreateFailed(),
    OrderCreateAnswered() ||
        OrderFindAnswered() ||
        OrderLockDue() ||
        OrderRefreshed() ||
        OrderRetryDue() ||
        OrderCommitPressed(),
  ) =>
    StepNext.stay(state),

  (
    OrderVerifying(:final request, :final attempt),
    OrderFindAnswered(attempt: final answered, :final read),
  )
      when answered == attempt =>
    _found(policy, request, attempt, read),
  (
    OrderVerifying(),
    OrderCreateAnswered() ||
        OrderFindAnswered() ||
        OrderLockDue() ||
        OrderRefreshed() ||
        OrderRetryDue() ||
        OrderRetryPressed() ||
        OrderCommitPressed() ||
        OrderBackPressed(),
  ) =>
    StepNext.stay(state),

  (OrderUnverified(:final request, :final attempt), OrderRetryPressed()) =>
    StepNext(OrderVerifying<R, O>(request, attempt), [
      OrderFindCreated(request, attempt),
    ]),
  (
    OrderUnverified(),
    OrderCreateAnswered() ||
        OrderFindAnswered() ||
        OrderLockDue() ||
        OrderRefreshed() ||
        OrderRetryDue() ||
        OrderCommitPressed(),
  ) =>
    StepNext.stay(state),

  (
    OrderQuoted(:final quoted, status: QuoteLive()),
    OrderLockDue(:final orderId),
  )
      when orderId == quoted.id =>
    StepNext(OrderQuoted<R, O>(quoted, const QuoteRefreshing(0)), [
      OrderRefresh(quoted.id),
    ]),
  (
    OrderQuoted(:final quoted, status: QuoteRefreshing(:final failures)),
    OrderRefreshed(:final orderId, :final read),
  )
      when orderId == quoted.id =>
    _refreshed(policy, quoted, failures, read),
  (
    OrderQuoted(:final quoted, status: QuoteRetrying(:final failures)),
    OrderRetryDue(:final orderId),
  )
      when orderId == quoted.id =>
    StepNext(OrderQuoted<R, O>(quoted, QuoteRefreshing(failures)), [
      OrderRefresh(quoted.id),
    ]),
  (
    OrderQuoted(:final quoted, status: QuoteUnavailable()),
    OrderRetryPressed(),
  ) =>
    StepNext(OrderQuoted<R, O>(quoted, const QuoteRefreshing(0)), [
      OrderRefresh(quoted.id),
    ]),
  (OrderQuoted(:final quoted, status: QuoteLive()), OrderCommitPressed()) =>
    StepNext(OrderCommitted<R, O>(quoted), [OrderStopTimers(quoted.id)]),
  (OrderQuoted(:final quoted), OrderBackPressed()) => StepNext(
    OrderLeft<R, O>(),
    [OrderStopTimers(quoted.id), OrderRelease(quoted.id)],
  ),
  (
    OrderQuoted(),
    OrderCreateAnswered() ||
        OrderFindAnswered() ||
        OrderLockDue() ||
        OrderRefreshed() ||
        OrderRetryDue() ||
        OrderRetryPressed() ||
        OrderCommitPressed(),
  ) =>
    StepNext.stay(state),

  (
    OrderPlaced() ||
        OrderCommitted() ||
        OrderAmountRefused() ||
        OrderSessionEnded() ||
        OrderLeft(),
    OrderCreateAnswered() ||
        OrderFindAnswered() ||
        OrderLockDue() ||
        OrderRefreshed() ||
        OrderRetryDue() ||
        OrderRetryPressed() ||
        OrderCommitPressed() ||
        OrderBackPressed(),
  ) =>
    StepNext.stay(state),
};
