import 'package:meta/meta.dart';

import 'outcome_watch_event.dart';

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
