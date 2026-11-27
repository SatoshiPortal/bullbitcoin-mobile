import 'package:meta/meta.dart';

import '../domain/exchange_failure.dart';
import 'step_next.dart';

import 'package:primitives/primitives.dart';

/// The consent gate's output. Only the gate makes one, so a funding rail
/// that requires consent and takes it can't be fetched without it.
@immutable
final class ConsentGiven {
  const ConsentGiven._();

  @override
  bool operator ==(Object other) => other is ConsentGiven;

  @override
  int get hashCode => (ConsentGiven).hashCode;
}

/// The consent gate (composition §4.10; fund, available to any flow).
/// Whether consent was already given comes from the loaded context, so a
/// lagging summary can't ask again (FUND-2, FUND-6).
@immutable
sealed class ConsentGateState {
  const ConsentGateState();

  ConsentGateNext next(ConsentGateEvent event) {
    final state = this;
    return switch ((state, event)) {
      (ConsentRequired(), ConsentStartPressed()) => const StepNext(
        ConsentAsking(),
      ),
      (ConsentAsking(), ConsentAcceptPressed()) => const StepNext(
        ConsentSubmitting(1),
        [ConsentSubmit(1)],
      ),
      (
        ConsentRequired() ||
            ConsentAsking() ||
            ConsentFailed() ||
            ConsentUnverified(),
        ConsentDeclinePressed(),
      ) =>
        const StepNext(ConsentDeclined()),
      (
        ConsentRequired(),
        ConsentAcceptPressed() ||
            ConsentSubmitted() ||
            ConsentVerified() ||
            ConsentRetryPressed(),
      ) =>
        StepNext.stay(state),
      (
        ConsentAsking(),
        ConsentStartPressed() ||
            ConsentSubmitted() ||
            ConsentVerified() ||
            ConsentRetryPressed(),
      ) =>
        StepNext.stay(state),

      (
        ConsentSubmitting(:final attempt),
        ConsentSubmitted(attempt: final answered, :final write),
      )
          when answered == attempt =>
        _submitted(attempt, write),
      (
        ConsentSubmitting(),
        ConsentStartPressed() ||
            ConsentAcceptPressed() ||
            ConsentDeclinePressed() ||
            ConsentSubmitted() ||
            ConsentVerified() ||
            ConsentRetryPressed(),
      ) =>
        StepNext.stay(state),

      (
        ConsentVerifying(:final attempt),
        ConsentVerified(attempt: final answered, :final read),
      )
          when answered == attempt =>
        _verified(attempt, read),
      (
        ConsentVerifying(),
        ConsentStartPressed() ||
            ConsentAcceptPressed() ||
            ConsentDeclinePressed() ||
            ConsentSubmitted() ||
            ConsentVerified() ||
            ConsentRetryPressed(),
      ) =>
        StepNext.stay(state),

      (ConsentFailed(:final attempt), ConsentRetryPressed()) => StepNext(
        ConsentSubmitting(attempt + 1),
        [ConsentSubmit(attempt + 1)],
      ),
      (ConsentUnverified(:final attempt), ConsentRetryPressed()) => StepNext(
        ConsentVerifying(attempt),
        [ConsentVerify(attempt)],
      ),
      (
        ConsentFailed() || ConsentUnverified(),
        ConsentStartPressed() ||
            ConsentAcceptPressed() ||
            ConsentSubmitted() ||
            ConsentVerified(),
      ) =>
        StepNext.stay(state),

      (
        ConsentGateGiven() || ConsentDeclined() || ConsentSessionEnded(),
        ConsentStartPressed() ||
            ConsentAcceptPressed() ||
            ConsentDeclinePressed() ||
            ConsentSubmitted() ||
            ConsentVerified() ||
            ConsentRetryPressed(),
      ) =>
        StepNext.stay(state),
    };
  }
}

final class ConsentRequired extends ConsentGateState {
  const ConsentRequired();
}

/// The consent text is shown.
final class ConsentAsking extends ConsentGateState {
  const ConsentAsking();
}

final class ConsentSubmitting extends ConsentGateState {
  final int attempt;

  const ConsentSubmitting(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConsentSubmitting && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConsentSubmitting, attempt);

  @override
  String toString() => 'ConsentSubmitting($attempt)';
}

/// The consent write may have reached the exchange: re-reading.
final class ConsentVerifying extends ConsentGateState {
  final int attempt;

  const ConsentVerifying(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConsentVerifying && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConsentVerifying, attempt);

  @override
  String toString() => 'ConsentVerifying($attempt)';
}

final class ConsentFailed extends ConsentGateState {
  final int attempt;
  final WriteProblem problem;

  const ConsentFailed(this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is ConsentFailed &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(ConsentFailed, attempt, problem);

  @override
  String toString() => 'ConsentFailed($attempt, $problem)';
}

/// The re-read failed; Retry reads again.
final class ConsentUnverified extends ConsentGateState {
  final int attempt;
  final ReadProblem problem;

  const ConsentUnverified(this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is ConsentUnverified &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(ConsentUnverified, attempt, problem);

  @override
  String toString() => 'ConsentUnverified($attempt, $problem)';
}

/// Output.
final class ConsentGateGiven extends ConsentGateState {
  final ConsentGiven given;

  const ConsentGateGiven(this.given);

  @override
  bool operator ==(Object other) =>
      other is ConsentGateGiven && other.given == given;

  @override
  int get hashCode => Object.hash(ConsentGateGiven, given);
}

/// The user declined or left. Terminal.
final class ConsentDeclined extends ConsentGateState {
  const ConsentDeclined();
}

/// A call got HTTP 401: the flow ends its session. Terminal.
final class ConsentSessionEnded extends ConsentGateState {
  const ConsentSessionEnded();
}

@immutable
sealed class ConsentGateEvent {
  const ConsentGateEvent();
}

final class ConsentStartPressed extends ConsentGateEvent {
  const ConsentStartPressed();
}

final class ConsentAcceptPressed extends ConsentGateEvent {
  const ConsentAcceptPressed();
}

final class ConsentDeclinePressed extends ConsentGateEvent {
  const ConsentDeclinePressed();
}

final class ConsentSubmitted extends ConsentGateEvent {
  final int attempt;
  final Result<void, ExchangeWriteFailure> write;

  const ConsentSubmitted(this.attempt, this.write);
}

/// The re-read of [attempt]: [Ok] holds whether consent is on the
/// account.
final class ConsentVerified extends ConsentGateEvent {
  final int attempt;
  final Result<bool, ExchangeReadFailure> read;

  const ConsentVerified(this.attempt, this.read);
}

final class ConsentRetryPressed extends ConsentGateEvent {
  const ConsentRetryPressed();
}

@immutable
sealed class ConsentGateEffect {
  const ConsentGateEffect();
}

/// Send the consent; answer [ConsentSubmitted] for [attempt].
final class ConsentSubmit extends ConsentGateEffect {
  final int attempt;

  const ConsentSubmit(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConsentSubmit && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConsentSubmit, attempt);
}

/// Read whether consent is on the account; answer [ConsentVerified].
final class ConsentVerify extends ConsentGateEffect {
  final int attempt;

  const ConsentVerify(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConsentVerify && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConsentVerify, attempt);
}

typedef ConsentGateNext = StepNext<ConsentGateState, ConsentGateEffect>;

const _given = StepNext<ConsentGateState, ConsentGateEffect>(
  ConsentGateGiven(ConsentGiven._()),
);

/// Given at once when the loaded context says consent is on the account.
ConsentGateNext consentGateStart({required bool alreadyGiven}) =>
    alreadyGiven ? _given : const StepNext(ConsentRequired());

ConsentGateNext _submitted(
  int attempt,
  Result<void, ExchangeWriteFailure> write,
) => switch (write) {
  Ok() => _given,
  Err(failure: ExchangeWriteRefusedFailure(:final reason)) => StepNext(
    ConsentFailed(attempt, WriteProblemRefused(reason)),
  ),
  Err(failure: ExchangeWriteNotSentFailure(:final reason)) => StepNext(
    ConsentFailed(attempt, WriteProblemNotSent(reason)),
  ),
  Err(failure: ExchangeWriteOutcomeUnknownFailure()) => StepNext(
    ConsentVerifying(attempt),
    [ConsentVerify(attempt)],
  ),
  Err(failure: ExchangeSessionRejectedFailure()) => const StepNext(
    ConsentSessionEnded(),
  ),
};

ConsentGateNext _verified(
  int attempt,
  Result<bool, ExchangeReadFailure> read,
) => switch (read) {
  Ok(value: true) => _given,
  Ok(value: false) => StepNext(
    ConsentFailed(attempt, const WriteProblemNotApplied()),
  ),
  Err(failure: ExchangeMissingFailure()) ||
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(
    failure: ExchangeMalformedFailure(),
  ) => StepNext(ConsentUnverified(attempt, ReadProblem.of(read)!)),
  Err(failure: ExchangeSessionRejectedFailure()) => const StepNext(
    ConsentSessionEnded(),
  ),
};
