import 'package:meta/meta.dart';

import '../domain/exchange_failure.dart';
import 'step_next.dart';

import 'package:primitives/primitives.dart';

enum OutcomeVerdict { done, failed, pending }

/// What a flow watches for, and the bounds of the watch.
@immutable
final class OutcomePolicy<O> {
  final String Function(O order) idOf;
  final OutcomeVerdict Function(O order) verdictOf;

  /// Whether a done order has a receipt to open (the payout rail's).
  final bool Function(O order) hasReceipt;

  /// Polls before the watch times out.
  final int maxPolls;

  /// Wall time before the watch times out. It keeps running while the watch
  /// is paused: it stands for the order's real deadline, which doesn't wait
  /// for the screen. A return after it shows TimedOut with Retry.
  final Duration maxDuration;

  /// Failed reads in a row before the outcome is unreadable.
  final int maxUnreadable;

  const OutcomePolicy({
    required this.idOf,
    required this.verdictOf,
    required this.hasReceipt,
    required this.maxPolls,
    required this.maxDuration,
    required this.maxUnreadable,
  });
}

/// Watching an order until its outcome (composition §4.9), bounded by a
/// poll count, a failed-read count and a deadline, and paused while the
/// screen is not visible (bbx_domain idea 3). Every poll answer carries the
/// ticket of the poll that asked; any other ticket is a stay, so a poll in
/// flight when the watch paused or ended lands nowhere.
@immutable
sealed class OutcomeWatchState<O> {
  const OutcomeWatchState();
}

final class WatchWatching<O> extends OutcomeWatchState<O> {
  final O order;
  final int polls;
  final int unreadable;
  final int ticket;

  const WatchWatching(this.order, this.polls, this.unreadable, this.ticket);

  @override
  bool operator ==(Object other) =>
      other is WatchWatching &&
      other.order == order &&
      other.polls == polls &&
      other.unreadable == unreadable &&
      other.ticket == ticket;

  @override
  int get hashCode =>
      Object.hash(WatchWatching, order, polls, unreadable, ticket);

  @override
  String toString() => 'WatchWatching($order, $polls, $unreadable, #$ticket)';
}

/// The screen is not visible: no poll runs. The deadline keeps running (it
/// is the order's real deadline, see [OutcomePolicy.maxDuration]).
final class WatchPaused<O> extends OutcomeWatchState<O> {
  final O order;
  final int polls;
  final int unreadable;
  final int ticket;

  const WatchPaused(this.order, this.polls, this.unreadable, this.ticket);

  @override
  bool operator ==(Object other) =>
      other is WatchPaused &&
      other.order == order &&
      other.polls == polls &&
      other.unreadable == unreadable &&
      other.ticket == ticket;

  @override
  int get hashCode =>
      Object.hash(WatchPaused, order, polls, unreadable, ticket);

  @override
  String toString() => 'WatchPaused($order, $polls, $unreadable, #$ticket)';
}

final class WatchDone<O> extends OutcomeWatchState<O> {
  final O order;

  const WatchDone(this.order);

  @override
  bool operator ==(Object other) => other is WatchDone && other.order == order;

  @override
  int get hashCode => Object.hash(WatchDone, order);

  @override
  String toString() => 'WatchDone($order)';
}

/// The payout rail's receipt of a done order is open.
final class WatchReceipt<O> extends OutcomeWatchState<O> {
  final O order;

  const WatchReceipt(this.order);

  @override
  bool operator ==(Object other) =>
      other is WatchReceipt && other.order == order;

  @override
  int get hashCode => Object.hash(WatchReceipt, order);
}

final class WatchFailed<O> extends OutcomeWatchState<O> {
  final O order;

  const WatchFailed(this.order);

  @override
  bool operator ==(Object other) =>
      other is WatchFailed && other.order == order;

  @override
  int get hashCode => Object.hash(WatchFailed, order);

  @override
  String toString() => 'WatchFailed($order)';
}

/// Too many failed reads in a row. [order] is the last one read; Retry
/// watches again from [nextTicket], Leave exits.
final class WatchUnreadable<O> extends OutcomeWatchState<O> {
  final O order;
  final int nextTicket;

  const WatchUnreadable(this.order, this.nextTicket);

  @override
  bool operator ==(Object other) =>
      other is WatchUnreadable &&
      other.order == order &&
      other.nextTicket == nextTicket;

  @override
  int get hashCode => Object.hash(WatchUnreadable, order, nextTicket);

  @override
  String toString() => 'WatchUnreadable($order, #$nextTicket)';
}

/// The poll count or the deadline ran out before an outcome. Retry watches
/// again from [nextTicket], Leave exits.
final class WatchTimedOut<O> extends OutcomeWatchState<O> {
  final O order;
  final int nextTicket;

  const WatchTimedOut(this.order, this.nextTicket);

  @override
  bool operator ==(Object other) =>
      other is WatchTimedOut &&
      other.order == order &&
      other.nextTicket == nextTicket;

  @override
  int get hashCode => Object.hash(WatchTimedOut, order, nextTicket);

  @override
  String toString() => 'WatchTimedOut($order, #$nextTicket)';
}

/// A poll got HTTP 401: the flow ends its session. Terminal.
final class WatchSessionEnded<O> extends OutcomeWatchState<O> {
  const WatchSessionEnded();

  @override
  bool operator ==(Object other) => other is WatchSessionEnded;

  @override
  int get hashCode => (WatchSessionEnded).hashCode;
}

/// The user left the outcome screen. Terminal.
final class WatchLeft<O> extends OutcomeWatchState<O> {
  const WatchLeft();

  @override
  bool operator ==(Object other) => other is WatchLeft;

  @override
  int get hashCode => (WatchLeft).hashCode;
}

@immutable
sealed class OutcomeWatchEvent<O> {
  const OutcomeWatchEvent();
}

/// The poll with [ticket] of [orderId] answered [read].
final class WatchPolled<O> extends OutcomeWatchEvent<O> {
  final String orderId;
  final int ticket;
  final Result<O, ExchangeReadFailure> read;

  const WatchPolled(this.orderId, this.ticket, this.read);
}

/// The outcome screen became visible or stopped being visible (app in the
/// background, another route on top).
final class WatchVisibilityChanged<O> extends OutcomeWatchEvent<O> {
  final bool visible;

  const WatchVisibilityChanged({required this.visible});
}

final class WatchDeadlinePassed<O> extends OutcomeWatchEvent<O> {
  final String orderId;

  const WatchDeadlinePassed(this.orderId);
}

final class WatchReceiptOpened<O> extends OutcomeWatchEvent<O> {
  const WatchReceiptOpened();
}

final class WatchReceiptClosed<O> extends OutcomeWatchEvent<O> {
  const WatchReceiptClosed();
}

final class WatchRetryPressed<O> extends OutcomeWatchEvent<O> {
  const WatchRetryPressed();
}

final class WatchLeavePressed<O> extends OutcomeWatchEvent<O> {
  const WatchLeavePressed();
}

@immutable
sealed class OutcomeWatchEffect {
  const OutcomeWatchEffect();
}

/// Read [orderId] after the poll interval (now when [immediate]); answer
/// [WatchPolled] with [ticket].
final class WatchSchedulePoll extends OutcomeWatchEffect {
  final String orderId;
  final int ticket;
  final bool immediate;

  const WatchSchedulePoll(this.orderId, this.ticket, {this.immediate = false});

  @override
  bool operator ==(Object other) =>
      other is WatchSchedulePoll &&
      other.orderId == orderId &&
      other.ticket == ticket &&
      other.immediate == immediate;

  @override
  int get hashCode =>
      Object.hash(WatchSchedulePoll, orderId, ticket, immediate);

  @override
  String toString() =>
      'WatchSchedulePoll($orderId, #$ticket${immediate ? ', now' : ''})';
}

/// Cancel the scheduled poll; the deadline keeps running.
final class WatchCancelPoll extends OutcomeWatchEffect {
  final String orderId;

  const WatchCancelPoll(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is WatchCancelPoll && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(WatchCancelPoll, orderId);

  @override
  String toString() => 'WatchCancelPoll($orderId)';
}

/// Answer [WatchDeadlinePassed] after [after].
final class WatchStartDeadline extends OutcomeWatchEffect {
  final String orderId;
  final Duration after;

  const WatchStartDeadline(this.orderId, this.after);

  @override
  bool operator ==(Object other) =>
      other is WatchStartDeadline &&
      other.orderId == orderId &&
      other.after == after;

  @override
  int get hashCode => Object.hash(WatchStartDeadline, orderId, after);

  @override
  String toString() => 'WatchStartDeadline($orderId, $after)';
}

/// Cancel the poll and the deadline.
final class WatchStop extends OutcomeWatchEffect {
  final String orderId;

  const WatchStop(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is WatchStop && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(WatchStop, orderId);

  @override
  String toString() => 'WatchStop($orderId)';
}

typedef OutcomeWatchNext<O> =
    StepNext<OutcomeWatchState<O>, OutcomeWatchEffect>;

OutcomeWatchNext<O> _watchFrom<O>(
  OutcomePolicy<O> policy,
  O order,
  int ticket,
) {
  final id = policy.idOf(order);
  return StepNext(WatchWatching<O>(order, 0, 0, ticket), [
    WatchStartDeadline(id, policy.maxDuration),
    WatchSchedulePoll(id, ticket, immediate: ticket > 1),
  ]);
}

/// The first state: an order that already has its outcome is done or failed
/// at once; otherwise the watch starts with its deadline and first poll.
OutcomeWatchNext<O> outcomeWatchStart<O>(OutcomePolicy<O> policy, O order) =>
    switch (policy.verdictOf(order)) {
      OutcomeVerdict.done => StepNext(WatchDone<O>(order)),
      OutcomeVerdict.failed => StepNext(WatchFailed<O>(order)),
      OutcomeVerdict.pending => _watchFrom(policy, order, 1),
    };

OutcomeWatchNext<O> _polled<O>(
  OutcomePolicy<O> policy,
  WatchWatching<O> watching,
  Result<O, ExchangeReadFailure> read,
) {
  final id = policy.idOf(watching.order);
  final polls = watching.polls + 1;
  final next = watching.ticket + 1;
  return switch (read) {
    Ok(:final value) => switch (policy.verdictOf(value)) {
      OutcomeVerdict.done => StepNext(WatchDone<O>(value), [WatchStop(id)]),
      OutcomeVerdict.failed => StepNext(WatchFailed<O>(value), [WatchStop(id)]),
      OutcomeVerdict.pending =>
        polls >= policy.maxPolls
            ? StepNext(WatchTimedOut<O>(value, next), [WatchStop(id)])
            : StepNext(WatchWatching<O>(value, polls, 0, next), [
                WatchSchedulePoll(id, next),
              ]),
    },
    Err(failure: ExchangeSessionRejectedFailure()) => StepNext(
      WatchSessionEnded<O>(),
      [WatchStop(id)],
    ),
    Err(failure: ExchangeMissingFailure()) ||
    Err(failure: ExchangeUnreachableFailure()) ||
    Err(failure: ExchangeMalformedFailure()) =>
      watching.unreadable + 1 >= policy.maxUnreadable
          ? StepNext(WatchUnreadable<O>(watching.order, next), [WatchStop(id)])
          : polls >= policy.maxPolls
          ? StepNext(WatchTimedOut<O>(watching.order, next), [WatchStop(id)])
          : StepNext(
              WatchWatching<O>(
                watching.order,
                polls,
                watching.unreadable + 1,
                next,
              ),
              [WatchSchedulePoll(id, next)],
            ),
  };
}

OutcomeWatchNext<O> transitionOutcomeWatch<O>(
  OutcomePolicy<O> policy,
  OutcomeWatchState<O> state,
  OutcomeWatchEvent<O> event,
) => switch ((state, event)) {
  (
    final WatchWatching<O> watching,
    WatchPolled(:final orderId, :final ticket, :final read),
  )
      when orderId == policy.idOf(watching.order) &&
          ticket == watching.ticket =>
    _polled(policy, watching, read),
  (
    WatchWatching(:final order, :final polls, :final unreadable, :final ticket),
    WatchVisibilityChanged(visible: false),
  ) =>
    StepNext(WatchPaused<O>(order, polls, unreadable, ticket + 1), [
      WatchCancelPoll(policy.idOf(order)),
    ]),
  (
    WatchWatching(:final order, :final ticket) ||
        WatchPaused(:final order, :final ticket),
    WatchDeadlinePassed(:final orderId),
  )
      when orderId == policy.idOf(order) =>
    StepNext(WatchTimedOut<O>(order, ticket + 1), [
      WatchStop(policy.idOf(order)),
    ]),
  (
    WatchWatching(:final order) || WatchPaused(:final order),
    WatchLeavePressed(),
  ) =>
    StepNext(WatchLeft<O>(), [WatchStop(policy.idOf(order))]),
  (
    WatchWatching(),
    WatchPolled() ||
        WatchVisibilityChanged() ||
        WatchDeadlinePassed() ||
        WatchReceiptOpened() ||
        WatchReceiptClosed() ||
        WatchRetryPressed(),
  ) =>
    StepNext.stay(state),

  (
    WatchPaused(:final order, :final polls, :final unreadable, :final ticket),
    WatchVisibilityChanged(visible: true),
  ) =>
    StepNext(WatchWatching<O>(order, polls, unreadable, ticket), [
      WatchSchedulePoll(policy.idOf(order), ticket, immediate: true),
    ]),
  (
    WatchPaused(),
    WatchPolled() ||
        WatchVisibilityChanged() ||
        WatchDeadlinePassed() ||
        WatchReceiptOpened() ||
        WatchReceiptClosed() ||
        WatchRetryPressed(),
  ) =>
    StepNext.stay(state),

  (WatchDone(:final order), WatchReceiptOpened())
      when policy.hasReceipt(order) =>
    StepNext(WatchReceipt<O>(order)),
  (WatchReceipt(:final order), WatchReceiptClosed()) => StepNext(
    WatchDone<O>(order),
  ),
  (
    WatchUnreadable(:final order, :final nextTicket) ||
        WatchTimedOut(:final order, :final nextTicket),
    WatchRetryPressed(),
  ) =>
    _watchFrom(policy, order, nextTicket),
  (
    WatchDone() ||
        WatchReceipt() ||
        WatchFailed() ||
        WatchUnreadable() ||
        WatchTimedOut(),
    WatchLeavePressed(),
  ) =>
    StepNext(WatchLeft<O>()),
  (
    WatchDone() ||
        WatchReceipt() ||
        WatchFailed() ||
        WatchUnreadable() ||
        WatchTimedOut(),
    WatchPolled() ||
        WatchVisibilityChanged() ||
        WatchDeadlinePassed() ||
        WatchReceiptOpened() ||
        WatchReceiptClosed() ||
        WatchRetryPressed(),
  ) =>
    StepNext.stay(state),

  (
    WatchSessionEnded() || WatchLeft(),
    WatchPolled() ||
        WatchVisibilityChanged() ||
        WatchDeadlinePassed() ||
        WatchReceiptOpened() ||
        WatchReceiptClosed() ||
        WatchRetryPressed() ||
        WatchLeavePressed(),
  ) =>
    StepNext.stay(state),
};
