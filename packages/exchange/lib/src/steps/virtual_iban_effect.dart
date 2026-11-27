import 'package:meta/meta.dart';

import 'virtual_iban_event.dart';
import 'virtual_iban_state.dart';

@immutable
sealed class VirtualIbanEffect {
  const VirtualIbanEffect();
}

/// Load the [VirtualIbanContext]; answer [VibanLoaded].
final class VibanLoad extends VirtualIbanEffect {
  final int attempt;

  const VibanLoad(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is VibanLoad && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(VibanLoad, attempt);
}

/// Create the virtual IBAN; answer [VibanCreated].
final class VibanCreate extends VirtualIbanEffect {
  final int attempt;

  const VibanCreate(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is VibanCreate && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(VibanCreate, attempt);
}

/// Read the virtual IBAN; answer [VibanVerified].
final class VibanVerify extends VirtualIbanEffect {
  final int attempt;

  const VibanVerify(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is VibanVerify && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(VibanVerify, attempt);
}

/// Read the virtual IBAN after the policy's interval, or at once; answer
/// [VibanPolled] for [ticket]. Replaces any poll scheduled before.
final class VibanSchedulePoll extends VirtualIbanEffect {
  final int ticket;
  final bool immediate;

  const VibanSchedulePoll(this.ticket, {this.immediate = false});

  @override
  bool operator ==(Object other) =>
      other is VibanSchedulePoll &&
      other.ticket == ticket &&
      other.immediate == immediate;

  @override
  int get hashCode => Object.hash(VibanSchedulePoll, ticket, immediate);
}

/// Cancel the scheduled poll (the screen is hidden).
final class VibanCancelPoll extends VirtualIbanEffect {
  const VibanCancelPoll();

  @override
  bool operator ==(Object other) => other is VibanCancelPoll;

  @override
  int get hashCode => (VibanCancelPoll).hashCode;
}

/// Answer [VibanDeadlinePassed] for [round] after [after].
final class VibanStartDeadline extends VirtualIbanEffect {
  final int round;
  final Duration after;

  const VibanStartDeadline(this.round, this.after);

  @override
  bool operator ==(Object other) =>
      other is VibanStartDeadline &&
      other.round == round &&
      other.after == after;

  @override
  int get hashCode => Object.hash(VibanStartDeadline, round, after);
}

/// Stop polling and the deadline.
final class VibanStopWatching extends VirtualIbanEffect {
  const VibanStopWatching();

  @override
  bool operator ==(Object other) => other is VibanStopWatching;

  @override
  int get hashCode => (VibanStopWatching).hashCode;
}
