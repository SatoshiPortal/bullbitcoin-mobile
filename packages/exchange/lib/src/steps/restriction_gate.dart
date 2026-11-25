import 'package:meta/meta.dart';

import 'step_next.dart';

/// The restriction gate's output: the loaded context says the account is
/// not restricted. Only the gate makes one.
@immutable
final class RestrictionCleared {
  const RestrictionCleared._();

  @override
  bool operator ==(Object other) => other is RestrictionCleared;

  @override
  int get hashCode => (RestrictionCleared).hashCode;
}

/// The restriction gate (composition §4.10; fund, AutoBuy), decided from the
/// loaded context only, never from a missing one: the flow can only start it
/// with a context it loaded.
@immutable
sealed class RestrictionGateState {
  const RestrictionGateState();
}

final class RestrictionAllowed extends RestrictionGateState {
  final RestrictionCleared cleared;

  const RestrictionAllowed(this.cleared);

  @override
  bool operator ==(Object other) =>
      other is RestrictionAllowed && other.cleared == cleared;

  @override
  int get hashCode => Object.hash(RestrictionAllowed, cleared);
}

/// The restricted view; its only exit is Leave (or a reload that clears it).
final class RestrictionRestricted extends RestrictionGateState {
  const RestrictionRestricted();
}

final class RestrictionLeft extends RestrictionGateState {
  const RestrictionLeft();
}

@immutable
sealed class RestrictionGateEvent {
  const RestrictionGateEvent();
}

/// The context was loaded again (pull to refresh, back from support).
final class RestrictionReloaded extends RestrictionGateEvent {
  final bool restricted;

  const RestrictionReloaded({required this.restricted});
}

final class RestrictionLeavePressed extends RestrictionGateEvent {
  const RestrictionLeavePressed();
}

/// The gate starts no effects; the type keeps the step shape.
@immutable
sealed class RestrictionGateEffect {
  const RestrictionGateEffect();
}

typedef RestrictionGateNext =
    StepNext<RestrictionGateState, RestrictionGateEffect>;

const _allowed = StepNext<RestrictionGateState, RestrictionGateEffect>(
  RestrictionAllowed(RestrictionCleared._()),
);

RestrictionGateNext restrictionGateStart({required bool restricted}) =>
    restricted ? const StepNext(RestrictionRestricted()) : _allowed;

RestrictionGateNext transitionRestrictionGate(
  RestrictionGateState state,
  RestrictionGateEvent event,
) => switch ((state, event)) {
  (RestrictionRestricted(), RestrictionReloaded(restricted: false)) => _allowed,
  (RestrictionRestricted(), RestrictionReloaded(restricted: true)) =>
    StepNext.stay(state),
  (RestrictionRestricted(), RestrictionLeavePressed()) => const StepNext(
    RestrictionLeft(),
  ),
  (
    RestrictionAllowed() || RestrictionLeft(),
    RestrictionReloaded() || RestrictionLeavePressed(),
  ) =>
    StepNext.stay(state),
};
