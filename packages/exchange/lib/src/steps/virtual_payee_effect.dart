import 'package:meta/meta.dart';

import 'virtual_payee_event.dart';

@immutable
sealed class VirtualPayeeEffect {
  const VirtualPayeeEffect();
}

/// Read the payee status; answer [PayeeLoaded].
final class PayeeLoad extends VirtualPayeeEffect {
  final int attempt;

  const PayeeLoad(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is PayeeLoad && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(PayeeLoad, attempt);
}

/// Activate the payee; answer [PayeeActivated].
final class PayeeActivate extends VirtualPayeeEffect {
  final int attempt;

  const PayeeActivate(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is PayeeActivate && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(PayeeActivate, attempt);
}

/// Read the status after [after]; answer [PayeePolled] for [ticket].
/// Replaces any poll scheduled before.
final class PayeeSchedulePoll extends VirtualPayeeEffect {
  final int ticket;
  final Duration after;

  const PayeeSchedulePoll(this.ticket, this.after);

  @override
  bool operator ==(Object other) =>
      other is PayeeSchedulePoll &&
      other.ticket == ticket &&
      other.after == after;

  @override
  int get hashCode => Object.hash(PayeeSchedulePoll, ticket, after);
}

final class PayeeCancelPoll extends VirtualPayeeEffect {
  const PayeeCancelPoll();

  @override
  bool operator ==(Object other) => other is PayeeCancelPoll;

  @override
  int get hashCode => (PayeeCancelPoll).hashCode;
}

/// Answer [PayeeDeadlinePassed] for [round] after [after].
final class PayeeStartDeadline extends VirtualPayeeEffect {
  final int round;
  final Duration after;

  const PayeeStartDeadline(this.round, this.after);

  @override
  bool operator ==(Object other) =>
      other is PayeeStartDeadline &&
      other.round == round &&
      other.after == after;

  @override
  int get hashCode => Object.hash(PayeeStartDeadline, round, after);
}

/// Stop polling and the deadline.
final class PayeeStopWatching extends VirtualPayeeEffect {
  const PayeeStopWatching();

  @override
  bool operator ==(Object other) => other is PayeeStopWatching;

  @override
  int get hashCode => (PayeeStopWatching).hashCode;
}
