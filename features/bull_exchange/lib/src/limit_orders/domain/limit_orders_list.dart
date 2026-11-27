import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The exchange keeps at most this many limit orders active per account.
const maximumActiveLimitOrders = 5;

/// The dashboard's active limit orders and "cancel all" (LIM-7). Loads and
/// the cancel-all share one attempt counter: an answer of an older attempt,
/// such as a list read that started before a cancel-all, is a stay.
@immutable
sealed class LimitOrdersListState {
  const LimitOrdersListState();

  int get attempt;
}

/// Why the shown list may not be current.
@immutable
sealed class LimitListProblem {
  const LimitListProblem();
}

/// The last refresh failed; the orders shown are the previous read.
final class ListRefreshFailed extends LimitListProblem {
  final ReadProblem problem;

  const ListRefreshFailed(this.problem);

  @override
  bool operator ==(Object other) =>
      other is ListRefreshFailed && other.problem == problem;

  @override
  int get hashCode => Object.hash(ListRefreshFailed, problem);
}

/// The write gate refused the cancel-all; nothing was sent.
final class ListCancelAllRefused extends LimitListProblem {
  final WriteGateRefusal refusal;

  const ListCancelAllRefused(this.refusal);

  @override
  bool operator ==(Object other) =>
      other is ListCancelAllRefused && other.refusal == refusal;

  @override
  int get hashCode => Object.hash(ListCancelAllRefused, refusal);
}

/// The cancel-all did not answer that it cancelled; the list read after it
/// still holds active orders.
final class ListCancelAllNotApplied extends LimitListProblem {
  const ListCancelAllNotApplied();

  @override
  bool operator ==(Object other) => other is ListCancelAllNotApplied;

  @override
  int get hashCode => (ListCancelAllNotApplied).hashCode;
}

/// The first read, nothing to show yet.
final class ListLoading extends LimitOrdersListState {
  @override
  final int attempt;

  const ListLoading(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ListLoading && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ListLoading, attempt);
}

/// Nothing could be read; Retry reads again.
final class ListFailed extends LimitOrdersListState {
  @override
  final int attempt;
  final ReadProblem problem;

  const ListFailed(this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is ListFailed &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(ListFailed, attempt, problem);
}

/// The account's session was refused; Retry reads again.
final class ListSignedOut extends LimitOrdersListState {
  @override
  final int attempt;

  const ListSignedOut(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ListSignedOut && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ListSignedOut, attempt);
}

final class ListShown extends LimitOrdersListState {
  final List<LimitOrder> orders;
  @override
  final int attempt;
  final LimitListProblem? problem;

  const ListShown(this.orders, this.attempt, {this.problem});

  bool get canCreate => orders.length < maximumActiveLimitOrders;

  @override
  bool operator ==(Object other) =>
      other is ListShown &&
      identical(other.orders, orders) &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(ListShown, orders.length, attempt, problem);
}

/// Reading again with [orders] still shown. [pending] is shown with the
/// read's orders if they are not empty (a cancel-all that did not answer).
final class ListRefreshing extends LimitOrdersListState {
  final List<LimitOrder> orders;
  @override
  final int attempt;
  final LimitListProblem? pending;

  const ListRefreshing(this.orders, this.attempt, {this.pending});

  @override
  bool operator ==(Object other) =>
      other is ListRefreshing &&
      identical(other.orders, orders) &&
      other.attempt == attempt &&
      other.pending == pending;

  @override
  int get hashCode =>
      Object.hash(ListRefreshing, orders.length, attempt, pending);
}

final class ListCancellingAll extends LimitOrdersListState {
  final List<LimitOrder> orders;
  @override
  final int attempt;

  const ListCancellingAll(this.orders, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ListCancellingAll &&
      identical(other.orders, orders) &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ListCancellingAll, orders.length, attempt);
}

/// What a cancel-all answered, closed.
@immutable
sealed class LimitCancelAllAnswer {
  const LimitCancelAllAnswer();
}

final class CancelAllDone extends LimitCancelAllAnswer {
  const CancelAllDone();
}

final class CancelAllGateRefused extends LimitCancelAllAnswer {
  final WriteGateRefusal refusal;

  const CancelAllGateRefused(this.refusal);
}

/// Anything else: some or all orders may be cancelled.
final class CancelAllUnsure extends LimitCancelAllAnswer {
  const CancelAllUnsure();
}

final class CancelAllSessionRejected extends LimitCancelAllAnswer {
  const CancelAllSessionRejected();
}

@immutable
sealed class LimitOrdersListEvent {
  const LimitOrdersListEvent();
}

final class ListLoaded extends LimitOrdersListEvent {
  final int attempt;
  final Result<List<LimitOrder>, ExchangeReadFailure> read;

  const ListLoaded(this.attempt, this.read);
}

/// A limit-order notification, the dashboard's refresh, or a return from
/// a create or details that changed something.
final class ListRefreshRequested extends LimitOrdersListEvent {
  const ListRefreshRequested();
}

final class ListRetryPressed extends LimitOrdersListEvent {
  const ListRetryPressed();
}

/// The user confirmed the cancel-all dialog.
final class ListCancelAllPressed extends LimitOrdersListEvent {
  const ListCancelAllPressed();
}

final class ListCancelAllAnswered extends LimitOrdersListEvent {
  final int attempt;
  final LimitCancelAllAnswer answer;

  const ListCancelAllAnswered(this.attempt, this.answer);
}

@immutable
sealed class LimitOrdersListEffect {
  const LimitOrdersListEffect();
}

final class ListFetch extends LimitOrdersListEffect {
  final int attempt;

  const ListFetch(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ListFetch && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ListFetch, attempt);
}

final class ListCancelAll extends LimitOrdersListEffect {
  final int attempt;

  const ListCancelAll(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ListCancelAll && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ListCancelAll, attempt);
}

typedef LimitOrdersListNext =
    StepNext<LimitOrdersListState, LimitOrdersListEffect>;

const limitOrdersListStart = LimitOrdersListNext(ListLoading(1), [
  ListFetch(1),
]);

LimitOrdersListNext _refresh(
  List<LimitOrder> orders,
  int attempt, {
  LimitListProblem? pending,
}) => LimitOrdersListNext(
  ListRefreshing(orders, attempt + 1, pending: pending),
  [ListFetch(attempt + 1)],
);

LimitOrdersListNext _reload(int attempt) =>
    LimitOrdersListNext(ListLoading(attempt + 1), [ListFetch(attempt + 1)]);

LimitOrdersListNext transitionLimitOrdersList(
  LimitOrdersListState state,
  LimitOrdersListEvent event,
) => switch ((state, event)) {
  (
    ListLoading(:final attempt),
    ListLoaded(attempt: final answered, :final read),
  )
      when answered == attempt =>
    LimitOrdersListNext(switch (read) {
      Ok(:final value) => ListShown(value, attempt),
      Err(failure: ExchangeSessionRejectedFailure()) => ListSignedOut(attempt),
      Err(failure: ExchangeMissingFailure()) ||
      Err(failure: ExchangeUnreachableFailure()) ||
      Err(
        failure: ExchangeMalformedFailure(),
      ) => ListFailed(attempt, ReadProblem.of(read)!),
    }),
  (
    ListLoading(),
    ListLoaded() ||
        ListRefreshRequested() ||
        ListRetryPressed() ||
        ListCancelAllPressed() ||
        ListCancelAllAnswered(),
  ) =>
    LimitOrdersListNext.stay(state),
  (
    ListFailed(:final attempt) || ListSignedOut(:final attempt),
    ListRetryPressed() || ListRefreshRequested(),
  ) =>
    _reload(attempt),
  (
    ListFailed() || ListSignedOut(),
    ListLoaded() || ListCancelAllPressed() || ListCancelAllAnswered(),
  ) =>
    LimitOrdersListNext.stay(state),
  (
    ListShown(:final orders, :final attempt),
    ListRefreshRequested() || ListRetryPressed(),
  ) =>
    _refresh(orders, attempt),
  (ListShown(:final orders, :final attempt), ListCancelAllPressed())
      when orders.isNotEmpty =>
    LimitOrdersListNext(ListCancellingAll(orders, attempt + 1), [
      ListCancelAll(attempt + 1),
    ]),
  (
    ListShown(),
    ListLoaded() || ListCancelAllPressed() || ListCancelAllAnswered(),
  ) =>
    LimitOrdersListNext.stay(state),
  (
    ListRefreshing(:final orders, :final attempt, :final pending),
    ListLoaded(attempt: final answered, :final read),
  )
      when answered == attempt =>
    LimitOrdersListNext(switch (read) {
      Ok(:final value) => ListShown(
        value,
        attempt,
        problem: value.isEmpty ? null : pending,
      ),
      Err(failure: ExchangeSessionRejectedFailure()) => ListSignedOut(attempt),
      Err(failure: ExchangeMissingFailure()) ||
      Err(failure: ExchangeUnreachableFailure()) ||
      Err(failure: ExchangeMalformedFailure()) => ListShown(
        orders,
        attempt,
        problem: ListRefreshFailed(ReadProblem.of(read)!),
      ),
    }),
  // A change seen while reading: the read in flight may predate it.
  (
    ListRefreshing(:final orders, :final attempt, :final pending),
    ListRefreshRequested(),
  ) =>
    _refresh(orders, attempt, pending: pending),
  (
    ListRefreshing(),
    ListLoaded() ||
        ListRetryPressed() ||
        ListCancelAllPressed() ||
        ListCancelAllAnswered(),
  ) =>
    LimitOrdersListNext.stay(state),
  (
    ListCancellingAll(:final orders, :final attempt),
    ListCancelAllAnswered(attempt: final answered, :final answer),
  )
      when answered == attempt =>
    switch (answer) {
      CancelAllDone() => _refresh(const [], attempt),
      CancelAllGateRefused(:final refusal) => LimitOrdersListNext(
        ListShown(orders, attempt, problem: ListCancelAllRefused(refusal)),
      ),
      CancelAllUnsure() => _refresh(
        orders,
        attempt,
        pending: const ListCancelAllNotApplied(),
      ),
      CancelAllSessionRejected() => LimitOrdersListNext(ListSignedOut(attempt)),
    },
  // The list is read again once the cancel-all answers.
  (
    ListCancellingAll(),
    ListLoaded() ||
        ListRefreshRequested() ||
        ListRetryPressed() ||
        ListCancelAllPressed() ||
        ListCancelAllAnswered(),
  ) =>
    LimitOrdersListNext.stay(state),
};
