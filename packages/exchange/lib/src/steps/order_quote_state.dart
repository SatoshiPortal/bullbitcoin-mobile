import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_access.dart';
import '../domain/exchange_failure.dart';
import '../domain/exchange_write_gate.dart';
import 'order_quote_effect.dart';
import 'order_quote_event.dart';
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

  OrderStepNext<R, O> next(OrderPolicy<O> policy, OrderStepEvent<R, O> event) {
    final state = this;
    return switch ((state, event)) {
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
  }
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
  required Future<Result<O, ExchangeWriteFailure>> Function(R request) create,
  required Future<void> Function(R request) journalUnknown,
}) async {
  final answer = await gate.run<Result<O, ExchangeGatedWriteFailure>>(
    session,
    FinancialWriteKind.orderCreate,
    () => create(effect.request),
    refused: refusedWrite,
  );
  if (answer case Err(failure: ExchangeWriteOutcomeUnknownFailure())) {
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
  Result<O, ExchangeGatedWriteFailure> answer,
) => switch (answer) {
  Err(failure: ExchangeWriteBusyFailure(:final refusal)) => StepNext(
    OrderWriteRefused<R, O>(request, attempt, refusal),
  ),
  Ok(:final value) => _held(policy, value),
  Err(
    failure: ExchangeWriteRefusedFailure(
      reason: ExchangeRefusal(orderLimit: final limit?),
    ),
  ) =>
    StepNext(OrderAmountRefused<R, O>(request, limit)),
  Err(failure: ExchangeWriteRefusedFailure(:final reason)) => StepNext(
    OrderCreateFailed<R, O>(request, attempt, WriteProblemRefused(reason)),
  ),
  Err(failure: ExchangeWriteNotSentFailure(:final reason)) => StepNext(
    OrderCreateFailed<R, O>(request, attempt, WriteProblemNotSent(reason)),
  ),
  Err(failure: ExchangeWriteOutcomeUnknownFailure()) => StepNext(
    OrderVerifying<R, O>(request, attempt),
    [OrderFindCreated(request, attempt)],
  ),
  Err(failure: ExchangeSessionRejectedFailure()) => StepNext(
    OrderSessionEnded<R, O>(),
  ),
};

OrderStepNext<R, O> _found<R, O>(
  OrderPolicy<O> policy,
  R request,
  int attempt,
  Result<O, ExchangeReadFailure> read,
) => switch (read) {
  Ok(:final value) => _held(policy, value),
  Err(failure: ExchangeMissingFailure()) => StepNext(
    OrderUnverified<R, O>(request, attempt, const ReadProblemMissing()),
  ),
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(
    failure: ExchangeMalformedFailure(),
  ) => StepNext(OrderUnverified<R, O>(request, attempt, ReadProblem.of(read)!)),
  Err(failure: ExchangeSessionRejectedFailure()) => StepNext(
    OrderSessionEnded<R, O>(),
  ),
};

OrderStepNext<R, O> _refreshed<R, O>(
  OrderPolicy<O> policy,
  QuotedOrder<O> quoted,
  int failures,
  Result<O, ExchangeReadFailure> read,
) => switch (read) {
  Ok(:final value) => StepNext(
    OrderQuoted<R, O>(QuotedOrder(quoted.id, value), const QuoteLive()),
    [OrderStartLockTimer(quoted.id)],
  ),
  Err(failure: ExchangeSessionRejectedFailure()) => StepNext(
    OrderSessionEnded<R, O>(),
    [OrderStopTimers(quoted.id)],
  ),
  Err(failure: ExchangeMissingFailure()) ||
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(failure: ExchangeMalformedFailure()) =>
    failures + 1 > policy.maxRefreshRetries
        ? StepNext(OrderQuoted<R, O>(quoted, const QuoteUnavailable()))
        : StepNext(OrderQuoted<R, O>(quoted, QuoteRetrying(failures + 1)), [
            OrderScheduleRefreshRetry(quoted.id, failures + 1),
          ]),
};
