import 'package:meta/meta.dart';

import '../domain/entities/virtual_iban.dart';
import '../domain/exchange_failure.dart';
import 'step_next.dart';

import 'package:primitives/primitives.dart';

/// What the virtual IBAN step loads first: the user's virtual IBAN, if any,
/// and the account owner's name the intro shows (the IBAN is issued in it).
@immutable
final class VirtualIbanContext {
  final VirtualIban? virtualIban;
  final String ownerName;

  const VirtualIbanContext({
    required this.virtualIban,
    required this.ownerName,
  });

  @override
  bool operator ==(Object other) =>
      other is VirtualIbanContext &&
      other.virtualIban == virtualIban &&
      other.ownerName == ownerName;

  @override
  int get hashCode => Object.hash(virtualIban, ownerName);
}

/// How long the step waits for a pending virtual IBAN (bbx_domain idea 3:
/// bounded, visibility-aware polling with an exit).
@immutable
final class VirtualIbanPolicy {
  final int maxPolls;
  final Duration pollEvery;
  final Duration maxDuration;

  const VirtualIbanPolicy({
    this.maxPolls = 120,
    this.pollEvery = const Duration(seconds: 5),
    this.maxDuration = const Duration(minutes: 10),
  });
}

/// The virtual IBAN requirement of Confidential SEPA (composition §4.5):
/// `Loading | Intro(owner) | Creating | Activating(poll) | Active | Failed |
/// TimedOut`, plus the states an unknown create outcome and a hidden screen
/// need.
@immutable
sealed class VirtualIbanState {
  const VirtualIbanState();
}

final class VibanLoading extends VirtualIbanState {
  final int attempt;

  const VibanLoading(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is VibanLoading && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(VibanLoading, attempt);

  @override
  String toString() => 'VibanLoading($attempt)';
}

final class VibanLoadFailed extends VirtualIbanState {
  final int attempt;
  final ReadProblem problem;

  const VibanLoadFailed(this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is VibanLoadFailed &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(VibanLoadFailed, attempt, problem);

  @override
  String toString() => 'VibanLoadFailed($attempt, $problem)';
}

/// The user has none: the intro offers to create one, or regular SEPA.
final class VibanIntro extends VirtualIbanState {
  final String ownerName;

  const VibanIntro(this.ownerName);

  @override
  bool operator ==(Object other) =>
      other is VibanIntro && other.ownerName == ownerName;

  @override
  int get hashCode => Object.hash(VibanIntro, ownerName);

  @override
  String toString() => 'VibanIntro';
}

final class VibanCreating extends VirtualIbanState {
  final String ownerName;
  final int attempt;

  const VibanCreating(this.ownerName, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is VibanCreating &&
      other.ownerName == ownerName &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(VibanCreating, ownerName, attempt);

  @override
  String toString() => 'VibanCreating($attempt)';
}

final class VibanCreateFailed extends VirtualIbanState {
  final String ownerName;
  final int attempt;
  final WriteProblem problem;

  const VibanCreateFailed(this.ownerName, this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is VibanCreateFailed &&
      other.ownerName == ownerName &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode =>
      Object.hash(VibanCreateFailed, ownerName, attempt, problem);

  @override
  String toString() => 'VibanCreateFailed($attempt, $problem)';
}

/// The create may have reached the exchange: re-reading, never creating
/// again.
final class VibanVerifying extends VirtualIbanState {
  final String ownerName;
  final int attempt;

  const VibanVerifying(this.ownerName, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is VibanVerifying &&
      other.ownerName == ownerName &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(VibanVerifying, ownerName, attempt);

  @override
  String toString() => 'VibanVerifying($attempt)';
}

/// The re-read failed; Retry reads again.
final class VibanUnverified extends VirtualIbanState {
  final String ownerName;
  final int attempt;
  final ReadProblem problem;

  const VibanUnverified(this.ownerName, this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is VibanUnverified &&
      other.ownerName == ownerName &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(VibanUnverified, ownerName, attempt, problem);

  @override
  String toString() => 'VibanUnverified($attempt, $problem)';
}

/// Pending: polled until active. [round] tags the deadline of this wait,
/// [ticket] the poll in flight, [polls] counts them.
final class VibanActivating extends VirtualIbanState {
  final String ownerName;
  final int round;
  final int ticket;
  final int polls;

  const VibanActivating(this.ownerName, this.round, this.ticket, this.polls);

  @override
  bool operator ==(Object other) =>
      other is VibanActivating &&
      other.ownerName == ownerName &&
      other.round == round &&
      other.ticket == ticket &&
      other.polls == polls;

  @override
  int get hashCode =>
      Object.hash(VibanActivating, ownerName, round, ticket, polls);

  @override
  String toString() => 'VibanActivating(r$round, t$ticket, $polls)';
}

/// Pending while the screen is not visible: no poll runs; the deadline
/// keeps running.
final class VibanPaused extends VirtualIbanState {
  final String ownerName;
  final int round;
  final int ticket;
  final int polls;

  const VibanPaused(this.ownerName, this.round, this.ticket, this.polls);

  @override
  bool operator ==(Object other) =>
      other is VibanPaused &&
      other.ownerName == ownerName &&
      other.round == round &&
      other.ticket == ticket &&
      other.polls == polls;

  @override
  int get hashCode => Object.hash(VibanPaused, ownerName, round, ticket, polls);

  @override
  String toString() => 'VibanPaused(r$round, t$ticket, $polls)';
}

/// Still pending after the policy's bounds; Retry waits another round.
final class VibanTimedOut extends VirtualIbanState {
  final String ownerName;
  final int round;
  final int ticket;

  const VibanTimedOut(this.ownerName, this.round, this.ticket);

  @override
  bool operator ==(Object other) =>
      other is VibanTimedOut &&
      other.ownerName == ownerName &&
      other.round == round &&
      other.ticket == ticket;

  @override
  int get hashCode => Object.hash(VibanTimedOut, ownerName, round, ticket);

  @override
  String toString() => 'VibanTimedOut(r$round, t$ticket)';
}

/// Output: the requirement is met.
final class VibanActive extends VirtualIbanState {
  final ActiveVirtualIban virtualIban;

  const VibanActive(this.virtualIban);

  @override
  bool operator ==(Object other) =>
      other is VibanActive && other.virtualIban == virtualIban;

  @override
  int get hashCode => Object.hash(VibanActive, virtualIban);

  @override
  String toString() => 'VibanActive';
}

/// The user chose regular SEPA instead. Terminal.
final class VibanDeclined extends VirtualIbanState {
  const VibanDeclined();
}

/// A call got HTTP 401. Terminal; the flow ends its session.
final class VibanSessionEnded extends VirtualIbanState {
  const VibanSessionEnded();
}

@immutable
sealed class VirtualIbanEvent {
  const VirtualIbanEvent();
}

final class VibanLoaded extends VirtualIbanEvent {
  final int attempt;
  final Result<VirtualIbanContext, ExchangeReadFailure> read;

  const VibanLoaded(this.attempt, this.read);
}

final class VibanCreatePressed extends VirtualIbanEvent {
  const VibanCreatePressed();
}

final class VibanCreated extends VirtualIbanEvent {
  final int attempt;
  final Result<VirtualIban, ExchangeWriteFailure> write;

  const VibanCreated(this.attempt, this.write);
}

/// The re-read after an unknown create; [Ok] of null means there is
/// none.
final class VibanVerified extends VirtualIbanEvent {
  final int attempt;
  final Result<VirtualIban?, ExchangeReadFailure> read;

  const VibanVerified(this.attempt, this.read);
}

final class VibanPolled extends VirtualIbanEvent {
  final int ticket;
  final Result<VirtualIban?, ExchangeReadFailure> read;

  const VibanPolled(this.ticket, this.read);
}

/// The server pushed `VIRTUAL_IBAN_ACTIVATED`: poll now.
final class VibanActivatedPushed extends VirtualIbanEvent {
  const VibanActivatedPushed();
}

final class VibanVisibilityChanged extends VirtualIbanEvent {
  final bool visible;

  const VibanVisibilityChanged({required this.visible});
}

final class VibanDeadlinePassed extends VirtualIbanEvent {
  final int round;

  const VibanDeadlinePassed(this.round);
}

final class VibanRetryPressed extends VirtualIbanEvent {
  const VibanRetryPressed();
}

/// Use regular SEPA instead.
final class VibanDeclinePressed extends VirtualIbanEvent {
  const VibanDeclinePressed();
}

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

typedef VirtualIbanNext = StepNext<VirtualIbanState, VirtualIbanEffect>;

VirtualIbanNext virtualIbanStart() =>
    const StepNext(VibanLoading(1), [VibanLoad(1)]);

VirtualIbanNext _watch(VirtualIbanPolicy policy, String owner, int round) =>
    StepNext(VibanActivating(owner, round, 1, 0), [
      const VibanSchedulePoll(1),
      VibanStartDeadline(round, policy.maxDuration),
    ]);

VirtualIbanNext _loaded(
  VirtualIbanPolicy policy,
  int attempt,
  Result<VirtualIbanContext, ExchangeReadFailure> read,
) => switch (read) {
  Ok(value: VirtualIbanContext(virtualIban: null, :final ownerName)) =>
    StepNext(VibanIntro(ownerName)),
  Ok(
    value: VirtualIbanContext(
      virtualIban: PendingVirtualIban(),
      :final ownerName,
    ),
  ) =>
    _watch(policy, ownerName, 1),
  Ok(value: VirtualIbanContext(virtualIban: final ActiveVirtualIban active)) =>
    StepNext(VibanActive(active)),
  Err(failure: ExchangeMissingFailure()) ||
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(
    failure: ExchangeMalformedFailure(),
  ) => StepNext(VibanLoadFailed(attempt, ReadProblem.of(read)!)),
  Err(failure: ExchangeSessionRejectedFailure()) => const StepNext(
    VibanSessionEnded(),
  ),
};

VirtualIbanNext _created(
  VirtualIbanPolicy policy,
  String owner,
  int attempt,
  Result<VirtualIban, ExchangeWriteFailure> write,
) => switch (write) {
  Ok(value: final ActiveVirtualIban active) => StepNext(VibanActive(active)),
  Ok(value: PendingVirtualIban()) => _watch(policy, owner, 1),
  Err(failure: ExchangeWriteRefusedFailure(:final reason)) => StepNext(
    VibanCreateFailed(owner, attempt, WriteProblemRefused(reason)),
  ),
  Err(failure: ExchangeWriteNotSentFailure(:final reason)) => StepNext(
    VibanCreateFailed(owner, attempt, WriteProblemNotSent(reason)),
  ),
  Err(failure: ExchangeWriteOutcomeUnknownFailure()) => StepNext(
    VibanVerifying(owner, attempt),
    [VibanVerify(attempt)],
  ),
  Err(failure: ExchangeSessionRejectedFailure()) => const StepNext(
    VibanSessionEnded(),
  ),
};

VirtualIbanNext _verified(
  VirtualIbanPolicy policy,
  String owner,
  int attempt,
  Result<VirtualIban?, ExchangeReadFailure> read,
) => switch (read) {
  Ok(value: final ActiveVirtualIban active) => StepNext(VibanActive(active)),
  Ok(value: PendingVirtualIban()) => _watch(policy, owner, 1),
  Ok(value: null) || Err(failure: ExchangeMissingFailure()) => StepNext(
    VibanCreateFailed(owner, attempt, const WriteProblemNotApplied()),
  ),
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(
    failure: ExchangeMalformedFailure(),
  ) => StepNext(VibanUnverified(owner, attempt, ReadProblem.of(read)!)),
  Err(failure: ExchangeSessionRejectedFailure()) => const StepNext(
    VibanSessionEnded(),
  ),
};

/// A poll answer that leaves it pending (or unreadable): poll again within
/// the bound, else time out.
VirtualIbanNext _pollAgain(VirtualIbanPolicy policy, VibanActivating at) {
  final polls = at.polls + 1;
  final ticket = at.ticket + 1;
  if (polls >= policy.maxPolls) {
    return StepNext(VibanTimedOut(at.ownerName, at.round, ticket), const [
      VibanStopWatching(),
    ]);
  }
  return StepNext(VibanActivating(at.ownerName, at.round, ticket, polls), [
    VibanSchedulePoll(ticket),
  ]);
}

VirtualIbanNext _polled(
  VirtualIbanPolicy policy,
  VibanActivating at,
  Result<VirtualIban?, ExchangeReadFailure> read,
) => switch (read) {
  Ok(value: final ActiveVirtualIban active) => StepNext(
    VibanActive(active),
    const [VibanStopWatching()],
  ),
  Ok(value: PendingVirtualIban() || null) ||
  Err(failure: ExchangeMissingFailure()) ||
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(failure: ExchangeMalformedFailure()) => _pollAgain(policy, at),
  Err(failure: ExchangeSessionRejectedFailure()) => const StepNext(
    VibanSessionEnded(),
    [VibanStopWatching()],
  ),
};

VirtualIbanNext transitionVirtualIban(
  VirtualIbanPolicy policy,
  VirtualIbanState state,
  VirtualIbanEvent event,
) => switch ((state, event)) {
  (VibanLoading(:final attempt), VibanLoaded(attempt: final at, :final read))
      when at == attempt =>
    _loaded(policy, attempt, read),
  (
    VibanLoading(),
    VibanLoaded() ||
        VibanCreatePressed() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanActivatedPushed() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed() ||
        VibanRetryPressed() ||
        VibanDeclinePressed(),
  ) =>
    StepNext.stay(state),

  (VibanLoadFailed(:final attempt), VibanRetryPressed()) => StepNext(
    VibanLoading(attempt + 1),
    [VibanLoad(attempt + 1)],
  ),
  (
    VibanLoadFailed() ||
        VibanIntro() ||
        VibanCreateFailed() ||
        VibanUnverified(),
    VibanDeclinePressed(),
  ) =>
    const StepNext(VibanDeclined()),
  (
    VibanLoadFailed(),
    VibanLoaded() ||
        VibanCreatePressed() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanActivatedPushed() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed(),
  ) =>
    StepNext.stay(state),

  (VibanIntro(:final ownerName), VibanCreatePressed()) => StepNext(
    VibanCreating(ownerName, 1),
    const [VibanCreate(1)],
  ),
  (
    VibanIntro(),
    VibanLoaded() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanActivatedPushed() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed() ||
        VibanRetryPressed(),
  ) =>
    StepNext.stay(state),

  (
    VibanCreating(:final ownerName, :final attempt),
    VibanCreated(attempt: final at, :final write),
  )
      when at == attempt =>
    _created(policy, ownerName, attempt, write),
  (
    VibanCreating(),
    VibanLoaded() ||
        VibanCreatePressed() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanActivatedPushed() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed() ||
        VibanRetryPressed() ||
        VibanDeclinePressed(),
  ) =>
    StepNext.stay(state),

  (VibanCreateFailed(:final ownerName, :final attempt), VibanRetryPressed()) =>
    StepNext(VibanCreating(ownerName, attempt + 1), [VibanCreate(attempt + 1)]),
  (
    VibanCreateFailed(),
    VibanLoaded() ||
        VibanCreatePressed() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanActivatedPushed() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed(),
  ) =>
    StepNext.stay(state),

  (
    VibanVerifying(:final ownerName, :final attempt),
    VibanVerified(attempt: final at, :final read),
  )
      when at == attempt =>
    _verified(policy, ownerName, attempt, read),
  (
    VibanVerifying(),
    VibanLoaded() ||
        VibanCreatePressed() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanActivatedPushed() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed() ||
        VibanRetryPressed() ||
        VibanDeclinePressed(),
  ) =>
    StepNext.stay(state),

  (VibanUnverified(:final ownerName, :final attempt), VibanRetryPressed()) =>
    StepNext(VibanVerifying(ownerName, attempt), [VibanVerify(attempt)]),
  (
    VibanUnverified(),
    VibanLoaded() ||
        VibanCreatePressed() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanActivatedPushed() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed(),
  ) =>
    StepNext.stay(state),

  (final VibanActivating at, VibanPolled(:final ticket, :final read))
      when ticket == at.ticket =>
    _polled(policy, at, read),
  (final VibanActivating at, VibanActivatedPushed()) => StepNext(
    VibanActivating(at.ownerName, at.round, at.ticket + 1, at.polls),
    [VibanSchedulePoll(at.ticket + 1, immediate: true)],
  ),
  (final VibanActivating at, VibanVisibilityChanged(visible: false)) =>
    StepNext(
      VibanPaused(at.ownerName, at.round, at.ticket + 1, at.polls),
      const [VibanCancelPoll()],
    ),
  (final VibanActivating at, VibanDeadlinePassed(:final round))
      when round == at.round =>
    StepNext(VibanTimedOut(at.ownerName, at.round, at.ticket + 1), const [
      VibanStopWatching(),
    ]),
  (VibanActivating() || VibanPaused(), VibanDeclinePressed()) => const StepNext(
    VibanDeclined(),
    [VibanStopWatching()],
  ),
  (
    VibanActivating(),
    VibanLoaded() ||
        VibanCreatePressed() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed() ||
        VibanRetryPressed(),
  ) =>
    StepNext.stay(state),

  (final VibanPaused at, VibanVisibilityChanged(visible: true)) => StepNext(
    VibanActivating(at.ownerName, at.round, at.ticket + 1, at.polls),
    [VibanSchedulePoll(at.ticket + 1, immediate: true)],
  ),
  (final VibanPaused at, VibanDeadlinePassed(:final round))
      when round == at.round =>
    StepNext(VibanTimedOut(at.ownerName, at.round, at.ticket + 1), const [
      VibanStopWatching(),
    ]),
  (
    VibanPaused(),
    VibanLoaded() ||
        VibanCreatePressed() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanActivatedPushed() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed() ||
        VibanRetryPressed(),
  ) =>
    StepNext.stay(state),

  (final VibanTimedOut at, VibanRetryPressed()) => StepNext(
    VibanActivating(at.ownerName, at.round + 1, at.ticket, 0),
    [
      VibanSchedulePoll(at.ticket, immediate: true),
      VibanStartDeadline(at.round + 1, policy.maxDuration),
    ],
  ),
  (VibanTimedOut(), VibanDeclinePressed()) => const StepNext(VibanDeclined()),
  (
    VibanTimedOut(),
    VibanLoaded() ||
        VibanCreatePressed() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanActivatedPushed() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed(),
  ) =>
    StepNext.stay(state),

  (
    VibanActive() || VibanDeclined() || VibanSessionEnded(),
    VibanLoaded() ||
        VibanCreatePressed() ||
        VibanCreated() ||
        VibanVerified() ||
        VibanPolled() ||
        VibanActivatedPushed() ||
        VibanVisibilityChanged() ||
        VibanDeadlinePassed() ||
        VibanRetryPressed() ||
        VibanDeclinePressed(),
  ) =>
    StepNext.stay(state),
};
