import 'package:meta/meta.dart';

import '../domain/exchange_failure.dart';
import '../payout/payout_requirement.dart';
import '../recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'step_next.dart';

import 'package:primitives/primitives.dart';

/// How the step polls a pending virtual payee: often at first, because
/// activation usually takes a few seconds, then less often, within bounds
/// (bbx_domain idea 3).
@immutable
final class VirtualPayeePolicy {
  final int fastPolls;
  final Duration fastEvery;
  final Duration every;
  final int maxPolls;
  final Duration maxDuration;

  const VirtualPayeePolicy({
    this.fastPolls = 8,
    this.fastEvery = const Duration(seconds: 1),
    this.every = const Duration(seconds: 5),
    this.maxPolls = 60,
    this.maxDuration = const Duration(minutes: 5),
  });

  Duration delayAfter(int polls) => polls < fastPolls ? fastEvery : every;
}

/// The virtual payee requirement of Confidential SEPA (composition §4.5):
/// `Loading | Absent | Activating | Pending(since) | Active | Failed(raw) |
/// TimedOut`. An absent payee is activated at once, as today.
@immutable
sealed class VirtualPayeeState {
  const VirtualPayeeState();

  VirtualPayeeNext next(VirtualPayeePolicy policy, VirtualPayeeEvent event) {
    final state = this;
    return switch ((state, event)) {
      (
        PayeeLoading(:final attempt),
        PayeeLoaded(attempt: final at, :final read),
      )
          when at == attempt =>
        _loaded(policy, attempt, read),
      (
        PayeeLoading(),
        PayeeLoaded() ||
            PayeeActivated() ||
            PayeePolled() ||
            PayeeVisibilityChanged() ||
            PayeeDeadlinePassed() ||
            PayeeRetryPressed() ||
            PayeeDeclinePressed(),
      ) =>
        StepNext.stay(state),

      (PayeeLoadFailed(:final attempt), PayeeRetryPressed()) ||
      (
        PayeeUnknownStatus(:final attempt),
        PayeeRetryPressed(),
      ) => StepNext(PayeeLoading(attempt + 1), [PayeeLoad(attempt + 1)]),
      (
        PayeeLoadFailed() ||
            PayeeActivateFailed() ||
            PayeeUnknownStatus() ||
            PayeeTimedOut(),
        PayeeDeclinePressed(),
      ) =>
        const StepNext(PayeeDeclined()),
      (
        PayeeLoadFailed() || PayeeUnknownStatus(),
        PayeeLoaded() ||
            PayeeActivated() ||
            PayeePolled() ||
            PayeeVisibilityChanged() ||
            PayeeDeadlinePassed(),
      ) =>
        StepNext.stay(state),

      (
        PayeeActivating(:final attempt),
        PayeeActivated(attempt: final at, :final write),
      )
          when at == attempt =>
        _activated(policy, attempt, write),
      (
        PayeeActivating(),
        PayeeLoaded() ||
            PayeeActivated() ||
            PayeePolled() ||
            PayeeVisibilityChanged() ||
            PayeeDeadlinePassed() ||
            PayeeRetryPressed() ||
            PayeeDeclinePressed(),
      ) =>
        StepNext.stay(state),

      (PayeeActivateFailed(:final attempt), PayeeRetryPressed()) => _activate(
        attempt + 1,
      ),
      (
        PayeeActivateFailed(),
        PayeeLoaded() ||
            PayeeActivated() ||
            PayeePolled() ||
            PayeeVisibilityChanged() ||
            PayeeDeadlinePassed(),
      ) =>
        StepNext.stay(state),

      (final PayeePending at, PayeePolled(:final ticket, :final read))
          when ticket == at.ticket =>
        _polled(policy, at, read),
      (final PayeePending at, PayeeVisibilityChanged(visible: false)) =>
        StepNext(
          PayeePaused(at.attempt, at.round, at.ticket + 1, at.polls),
          const [PayeeCancelPoll()],
        ),
      (final PayeePending at, PayeeDeadlinePassed(:final round))
          when round == at.round =>
        StepNext(PayeeTimedOut(at.attempt, at.round, at.ticket + 1), const [
          PayeeStopWatching(),
        ]),
      (PayeePending() || PayeePaused(), PayeeDeclinePressed()) =>
        const StepNext(PayeeDeclined(), [PayeeStopWatching()]),
      (
        PayeePending(),
        PayeeLoaded() ||
            PayeeActivated() ||
            PayeePolled() ||
            PayeeVisibilityChanged() ||
            PayeeDeadlinePassed() ||
            PayeeRetryPressed(),
      ) =>
        StepNext.stay(state),

      (final PayeePaused at, PayeeVisibilityChanged(visible: true)) => StepNext(
        PayeePending(at.attempt, at.round, at.ticket + 1, at.polls),
        [PayeeSchedulePoll(at.ticket + 1, Duration.zero)],
      ),
      (final PayeePaused at, PayeeDeadlinePassed(:final round))
          when round == at.round =>
        StepNext(PayeeTimedOut(at.attempt, at.round, at.ticket + 1), const [
          PayeeStopWatching(),
        ]),
      (
        PayeePaused(),
        PayeeLoaded() ||
            PayeeActivated() ||
            PayeePolled() ||
            PayeeVisibilityChanged() ||
            PayeeDeadlinePassed() ||
            PayeeRetryPressed(),
      ) =>
        StepNext.stay(state),

      (final PayeeTimedOut at, PayeeRetryPressed()) => StepNext(
        PayeePending(at.attempt, at.round + 1, at.ticket, 0),
        [
          PayeeSchedulePoll(at.ticket, Duration.zero),
          PayeeStartDeadline(at.round + 1, policy.maxDuration),
        ],
      ),
      (
        PayeeTimedOut(),
        PayeeLoaded() ||
            PayeeActivated() ||
            PayeePolled() ||
            PayeeVisibilityChanged() ||
            PayeeDeadlinePassed(),
      ) =>
        StepNext.stay(state),

      (
        PayeeActive() || PayeeDeclined() || PayeeSessionEnded(),
        PayeeLoaded() ||
            PayeeActivated() ||
            PayeePolled() ||
            PayeeVisibilityChanged() ||
            PayeeDeadlinePassed() ||
            PayeeRetryPressed() ||
            PayeeDeclinePressed(),
      ) =>
        StepNext.stay(state),
    };
  }
}

final class PayeeLoading extends VirtualPayeeState {
  final int attempt;

  const PayeeLoading(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is PayeeLoading && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(PayeeLoading, attempt);

  @override
  String toString() => 'PayeeLoading($attempt)';
}

final class PayeeLoadFailed extends VirtualPayeeState {
  final int attempt;
  final ReadProblem problem;

  const PayeeLoadFailed(this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is PayeeLoadFailed &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(PayeeLoadFailed, attempt, problem);

  @override
  String toString() => 'PayeeLoadFailed($attempt, $problem)';
}

final class PayeeActivating extends VirtualPayeeState {
  final int attempt;

  const PayeeActivating(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is PayeeActivating && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(PayeeActivating, attempt);

  @override
  String toString() => 'PayeeActivating($attempt)';
}

final class PayeeActivateFailed extends VirtualPayeeState {
  final int attempt;
  final WriteProblem problem;

  const PayeeActivateFailed(this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is PayeeActivateFailed &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(PayeeActivateFailed, attempt, problem);

  @override
  String toString() => 'PayeeActivateFailed($attempt, $problem)';
}

/// Activation asked (or its outcome unknown): polled until active.
/// [attempt] is the last activation, [round] tags this wait's deadline,
/// [ticket] the poll in flight.
final class PayeePending extends VirtualPayeeState {
  final int attempt;
  final int round;
  final int ticket;
  final int polls;

  const PayeePending(this.attempt, this.round, this.ticket, this.polls);

  @override
  bool operator ==(Object other) =>
      other is PayeePending &&
      other.attempt == attempt &&
      other.round == round &&
      other.ticket == ticket &&
      other.polls == polls;

  @override
  int get hashCode => Object.hash(PayeePending, attempt, round, ticket, polls);

  @override
  String toString() => 'PayeePending(a$attempt, r$round, t$ticket, $polls)';
}

/// Pending while the screen is hidden: no poll; the deadline keeps running.
final class PayeePaused extends VirtualPayeeState {
  final int attempt;
  final int round;
  final int ticket;
  final int polls;

  const PayeePaused(this.attempt, this.round, this.ticket, this.polls);

  @override
  bool operator ==(Object other) =>
      other is PayeePaused &&
      other.attempt == attempt &&
      other.round == round &&
      other.ticket == ticket &&
      other.polls == polls;

  @override
  int get hashCode => Object.hash(PayeePaused, attempt, round, ticket, polls);

  @override
  String toString() => 'PayeePaused(a$attempt, r$round, t$ticket, $polls)';
}

final class PayeeTimedOut extends VirtualPayeeState {
  final int attempt;
  final int round;
  final int ticket;

  const PayeeTimedOut(this.attempt, this.round, this.ticket);

  @override
  bool operator ==(Object other) =>
      other is PayeeTimedOut &&
      other.attempt == attempt &&
      other.round == round &&
      other.ticket == ticket;

  @override
  int get hashCode => Object.hash(PayeeTimedOut, attempt, round, ticket);

  @override
  String toString() => 'PayeeTimedOut(a$attempt, r$round, t$ticket)';
}

/// The server holds a status this build doesn't know (e.g. a refused
/// payee): nothing polls or activates it again by itself. Retry reads it
/// again; Decline uses regular SEPA.
final class PayeeUnknownStatus extends VirtualPayeeState {
  final int attempt;

  const PayeeUnknownStatus(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is PayeeUnknownStatus && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(PayeeUnknownStatus, attempt);

  @override
  String toString() => 'PayeeUnknownStatus($attempt)';
}

/// Output: the requirement is met.
final class PayeeActive extends VirtualPayeeState {
  const PayeeActive();
}

/// The user chose regular SEPA instead. Terminal.
final class PayeeDeclined extends VirtualPayeeState {
  const PayeeDeclined();
}

/// A call got HTTP 401. Terminal; the flow ends its session.
final class PayeeSessionEnded extends VirtualPayeeState {
  const PayeeSessionEnded();
}

@immutable
sealed class VirtualPayeeEvent {
  const VirtualPayeeEvent();
}

/// [ExchangeMissingFailure]: the user has no SEPA recipient with this id.
final class PayeeLoaded extends VirtualPayeeEvent {
  final int attempt;
  final Result<SepaVirtualPayeeStatus, ExchangeReadFailure> read;

  const PayeeLoaded(this.attempt, this.read);
}

final class PayeeActivated extends VirtualPayeeEvent {
  final int attempt;
  final Result<SepaVirtualPayeeStatus, ExchangeWriteFailure> write;

  const PayeeActivated(this.attempt, this.write);
}

final class PayeePolled extends VirtualPayeeEvent {
  final int ticket;
  final Result<SepaVirtualPayeeStatus, ExchangeReadFailure> read;

  const PayeePolled(this.ticket, this.read);
}

final class PayeeVisibilityChanged extends VirtualPayeeEvent {
  final bool visible;

  const PayeeVisibilityChanged({required this.visible});
}

final class PayeeDeadlinePassed extends VirtualPayeeEvent {
  final int round;

  const PayeeDeadlinePassed(this.round);
}

final class PayeeRetryPressed extends VirtualPayeeEvent {
  const PayeeRetryPressed();
}

/// Use regular SEPA instead.
final class PayeeDeclinePressed extends VirtualPayeeEvent {
  const PayeeDeclinePressed();
}

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

typedef VirtualPayeeNext = StepNext<VirtualPayeeState, VirtualPayeeEffect>;

/// A payee the recipient list already shows active passes at once (no
/// screen).
VirtualPayeeNext virtualPayeeStart(VirtualPayeeRequired requirement) =>
    requirement.alreadyActive
    ? const StepNext(PayeeActive())
    : const StepNext(PayeeLoading(1), [PayeeLoad(1)]);

VirtualPayeeNext _wait(VirtualPayeePolicy policy, int attempt, int round) =>
    StepNext(PayeePending(attempt, round, 1, 0), [
      PayeeSchedulePoll(1, policy.delayAfter(0)),
      PayeeStartDeadline(round, policy.maxDuration),
    ]);

VirtualPayeeNext _activate(int attempt) =>
    StepNext(PayeeActivating(attempt), [PayeeActivate(attempt)]);

VirtualPayeeNext _loaded(
  VirtualPayeePolicy policy,
  int attempt,
  Result<SepaVirtualPayeeStatus, ExchangeReadFailure> read,
) => switch (read) {
  Ok(value: SepaVirtualPayeeStatus.active) => const StepNext(PayeeActive()),
  Ok(value: SepaVirtualPayeeStatus.absent) => _activate(1),
  Ok(value: SepaVirtualPayeeStatus.pending) => _wait(policy, 0, 1),
  Ok(value: SepaVirtualPayeeStatus.unknown) => StepNext(
    PayeeUnknownStatus(attempt),
  ),
  Err(failure: ExchangeMissingFailure()) ||
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(
    failure: ExchangeMalformedFailure(),
  ) => StepNext(PayeeLoadFailed(attempt, ReadProblem.of(read)!)),
  Err(failure: ExchangeSessionRejectedFailure()) => const StepNext(
    PayeeSessionEnded(),
  ),
};

VirtualPayeeNext _activated(
  VirtualPayeePolicy policy,
  int attempt,
  Result<SepaVirtualPayeeStatus, ExchangeWriteFailure> write,
) => switch (write) {
  Ok(value: SepaVirtualPayeeStatus.active) => const StepNext(PayeeActive()),
  Ok(value: SepaVirtualPayeeStatus.pending || SepaVirtualPayeeStatus.absent) ||
  Err(
    failure: ExchangeWriteOutcomeUnknownFailure(),
  ) => _wait(policy, attempt, 1),
  Ok(value: SepaVirtualPayeeStatus.unknown) => StepNext(
    PayeeUnknownStatus(attempt),
  ),
  Err(failure: ExchangeWriteRefusedFailure(:final reason)) => StepNext(
    PayeeActivateFailed(attempt, WriteProblemRefused(reason)),
  ),
  Err(failure: ExchangeWriteNotSentFailure(:final reason)) => StepNext(
    PayeeActivateFailed(attempt, WriteProblemNotSent(reason)),
  ),
  Err(failure: ExchangeSessionRejectedFailure()) => const StepNext(
    PayeeSessionEnded(),
  ),
};

VirtualPayeeNext _pollAgain(VirtualPayeePolicy policy, PayeePending at) {
  final polls = at.polls + 1;
  final ticket = at.ticket + 1;
  if (polls >= policy.maxPolls) {
    return StepNext(PayeeTimedOut(at.attempt, at.round, ticket), const [
      PayeeStopWatching(),
    ]);
  }
  return StepNext(PayeePending(at.attempt, at.round, ticket, polls), [
    PayeeSchedulePoll(ticket, policy.delayAfter(polls)),
  ]);
}

VirtualPayeeNext _polled(
  VirtualPayeePolicy policy,
  PayeePending at,
  Result<SepaVirtualPayeeStatus, ExchangeReadFailure> read,
) => switch (read) {
  Ok(value: SepaVirtualPayeeStatus.active) => const StepNext(PayeeActive(), [
    PayeeStopWatching(),
  ]),
  Ok(value: SepaVirtualPayeeStatus.pending) ||
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(failure: ExchangeMalformedFailure()) => _pollAgain(policy, at),
  // The activation did not take: offer it again.
  Ok(value: SepaVirtualPayeeStatus.absent) => StepNext(
    PayeeActivateFailed(at.attempt, const WriteProblemNotApplied()),
    const [PayeeStopWatching()],
  ),
  Ok(value: SepaVirtualPayeeStatus.unknown) => StepNext(
    PayeeUnknownStatus(at.attempt),
    const [PayeeStopWatching()],
  ),
  Err(failure: ExchangeMissingFailure()) => StepNext(
    PayeeLoadFailed(at.attempt, const ReadProblemMissing()),
    const [PayeeStopWatching()],
  ),
  Err(failure: ExchangeSessionRejectedFailure()) => const StepNext(
    PayeeSessionEnded(),
    [PayeeStopWatching()],
  ),
};
