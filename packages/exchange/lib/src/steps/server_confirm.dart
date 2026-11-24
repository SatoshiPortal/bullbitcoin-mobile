import 'package:meta/meta.dart';

import '../domain/exchange_access.dart';
import '../domain/exchange_call_result.dart';
import '../domain/exchange_write_gate.dart';
import '../domain/unknown_write_journal.dart';
import 'step_next.dart';

/// The commit step's output. The server confirm gives [ServerConfirmed];
/// the payin step (C4) adds its own variant, so every switch over a commit
/// must name it then.
@immutable
sealed class CommittedOrder<C> {
  const CommittedOrder();
}

final class ServerConfirmed<C> extends CommittedOrder<C> {
  final C confirmed;

  const ServerConfirmed(this.confirmed);

  @override
  bool operator ==(Object other) =>
      other is ServerConfirmed && other.confirmed == confirmed;

  @override
  int get hashCode => Object.hash(ServerConfirmed, confirmed);
}

/// Which write a server confirm is, and how its journal entry is found.
@immutable
final class ServerConfirmPolicy<T> {
  final FinancialWriteKind writeKind;
  final UnknownWriteKind journalKind;

  /// The order id the journal records for [T]; null for writes journaled
  /// without one (DCA create, limit-order create, default wallet save).
  final String? Function(T target) resourceIdOf;

  const ServerConfirmPolicy({
    required this.writeKind,
    required this.journalKind,
    required this.resourceIdOf,
  });

  /// Whether [entry] is this write of [target].
  bool matches(UnknownWrite entry, T target) {
    if (entry.kind != journalKind) return false;
    final id = resourceIdOf(target);
    return id == null || entry.orderId == id;
  }
}

/// The open journal entry of [target]'s write, if any. A flow whose write
/// has one starts the confirm in Verifying, never offering the write again.
UnknownWrite? openEntryFor<T>(
  ServerConfirmPolicy<T> policy,
  T target,
  List<UnknownWrite> openEntries,
) {
  for (final entry in openEntries) {
    if (policy.matches(entry, target)) return entry;
  }
  return null;
}

/// A server confirm (composition §4.8): buy and withdraw confirm, DCA and
/// limit-order create, AutoBuy activation. [T] is what is confirmed (a
/// quoted order, a request), [C] what the server answers.
///
/// The commit was pressed in the previous step; it can be pressed again only
/// in [ConfirmFailed]. An unknown outcome leads to [ConfirmVerifying], which
/// re-reads and never sends the write again.
@immutable
sealed class ServerConfirmState<T, C> {
  const ServerConfirmState();
}

final class ConfirmConfirming<T, C> extends ServerConfirmState<T, C> {
  final T target;
  final int attempt;

  const ConfirmConfirming(this.target, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConfirmConfirming &&
      other.target == target &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConfirmConfirming, target, attempt);

  @override
  String toString() => 'ConfirmConfirming($target, $attempt)';
}

/// The account's write gate refused the write; nothing was sent.
final class ConfirmWriteRefused<T, C> extends ServerConfirmState<T, C> {
  final T target;
  final int attempt;
  final WriteGateRefusal refusal;

  const ConfirmWriteRefused(this.target, this.attempt, this.refusal);

  @override
  bool operator ==(Object other) =>
      other is ConfirmWriteRefused &&
      other.target == target &&
      other.attempt == attempt &&
      other.refusal == refusal;

  @override
  int get hashCode =>
      Object.hash(ConfirmWriteRefused, target, attempt, refusal);

  @override
  String toString() => 'ConfirmWriteRefused($target, $attempt, $refusal)';
}

/// Output.
final class ConfirmConfirmed<T, C> extends ServerConfirmState<T, C> {
  final C confirmed;

  const ConfirmConfirmed(this.confirmed);

  CommittedOrder<C> get committed => ServerConfirmed(confirmed);

  @override
  bool operator ==(Object other) =>
      other is ConfirmConfirmed && other.confirmed == confirmed;

  @override
  int get hashCode => Object.hash(ConfirmConfirmed, confirmed);

  @override
  String toString() => 'ConfirmConfirmed($confirmed)';
}

/// The write did not take effect. The only state that offers it again.
final class ConfirmFailed<T, C> extends ServerConfirmState<T, C> {
  final T target;
  final int attempt;
  final WriteProblem problem;

  const ConfirmFailed(this.target, this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is ConfirmFailed &&
      other.target == target &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(ConfirmFailed, target, attempt, problem);

  @override
  String toString() => 'ConfirmFailed($target, $attempt, $problem)';
}

/// The write may have taken effect: re-reading. Back is a stay.
final class ConfirmVerifying<T, C> extends ServerConfirmState<T, C> {
  final T target;
  final int attempt;

  const ConfirmVerifying(this.target, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConfirmVerifying &&
      other.target == target &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConfirmVerifying, target, attempt);

  @override
  String toString() => 'ConfirmVerifying($target, $attempt)';
}

/// The re-read failed. Retry reads again; leaving keeps the journal entry,
/// which the next sign-in reconciles.
final class ConfirmUnverified<T, C> extends ServerConfirmState<T, C> {
  final T target;
  final int attempt;
  final ReadProblem problem;

  const ConfirmUnverified(this.target, this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is ConfirmUnverified &&
      other.target == target &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(ConfirmUnverified, target, attempt, problem);

  @override
  String toString() => 'ConfirmUnverified($target, $attempt, $problem)';
}

/// A call got HTTP 401: the flow ends its session. Terminal.
final class ConfirmSessionEnded<T, C> extends ServerConfirmState<T, C> {
  const ConfirmSessionEnded();

  @override
  bool operator ==(Object other) => other is ConfirmSessionEnded;

  @override
  int get hashCode => (ConfirmSessionEnded).hashCode;
}

/// The user went back. Terminal.
final class ConfirmLeft<T, C> extends ServerConfirmState<T, C> {
  const ConfirmLeft();

  @override
  bool operator ==(Object other) => other is ConfirmLeft;

  @override
  int get hashCode => (ConfirmLeft).hashCode;
}

/// What the re-read after an unknown outcome shows.
@immutable
sealed class ConfirmCheck<C> {
  const ConfirmCheck();
}

final class ConfirmSeenApplied<C> extends ConfirmCheck<C> {
  final C confirmed;

  const ConfirmSeenApplied(this.confirmed);
}

final class ConfirmSeenNotApplied<C> extends ConfirmCheck<C> {
  const ConfirmSeenNotApplied();
}

final class ConfirmCheckFailed<C> extends ConfirmCheck<C> {
  final ReadProblem problem;

  const ConfirmCheckFailed(this.problem);
}

final class ConfirmCheckSessionRejected<C> extends ConfirmCheck<C> {
  const ConfirmCheckSessionRejected();
}

@immutable
sealed class ServerConfirmEvent<T, C> {
  const ServerConfirmEvent();
}

/// What the write gate and the write of [attempt] answered.
final class ConfirmAnswered<T, C> extends ServerConfirmEvent<T, C> {
  final int attempt;
  final GatedWrite<ExchangeWrite<C>> answer;

  const ConfirmAnswered(this.attempt, this.answer);
}

final class ConfirmVerified<T, C> extends ServerConfirmEvent<T, C> {
  final int attempt;
  final ConfirmCheck<C> check;

  const ConfirmVerified(this.attempt, this.check);
}

final class ConfirmCommitPressed<T, C> extends ServerConfirmEvent<T, C> {
  const ConfirmCommitPressed();
}

final class ConfirmRetryPressed<T, C> extends ServerConfirmEvent<T, C> {
  const ConfirmRetryPressed();
}

final class ConfirmBackPressed<T, C> extends ServerConfirmEvent<T, C> {
  const ConfirmBackPressed();
}

@immutable
sealed class ServerConfirmEffect<T> {
  const ServerConfirmEffect();
}

/// Send the write through the account's gate ([runServerConfirm]); answer
/// [ConfirmAnswered] for [attempt].
final class ConfirmSend<T> extends ServerConfirmEffect<T> {
  final T target;
  final int attempt;

  const ConfirmSend(this.target, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConfirmSend &&
      other.target == target &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConfirmSend, target, attempt);

  @override
  String toString() => 'ConfirmSend($target, $attempt)';
}

/// Re-read what the write would have changed; answer [ConfirmVerified].
final class ConfirmVerify<T> extends ServerConfirmEffect<T> {
  final T target;
  final int attempt;

  const ConfirmVerify(this.target, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConfirmVerify &&
      other.target == target &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConfirmVerify, target, attempt);

  @override
  String toString() => 'ConfirmVerify($target, $attempt)';
}

typedef ServerConfirmNext<T, C> =
    StepNext<ServerConfirmState<T, C>, ServerConfirmEffect<T>>;

/// The first state: [ConfirmVerifying] when [openEntry] (see [openEntryFor])
/// says the write may already have reached the exchange, else
/// [ConfirmConfirming].
ServerConfirmNext<T, C> serverConfirmStart<T, C>(
  T target, {
  UnknownWrite? openEntry,
}) => openEntry == null
    ? StepNext(ConfirmConfirming<T, C>(target, 1), [ConfirmSend(target, 1)])
    : StepNext(ConfirmVerifying<T, C>(target, 1), [ConfirmVerify(target, 1)]);

/// Runs [ConfirmSend] through [gate] for [session]'s account.
Future<ConfirmAnswered<T, C>> runServerConfirm<T, C>({
  required ExchangeWriteGate gate,
  required ExchangeSession session,
  required ServerConfirmPolicy<T> policy,
  required ConfirmSend<T> effect,
  required Future<ExchangeWrite<C>> Function(T target) confirm,
}) async => ConfirmAnswered(
  effect.attempt,
  await gate.run(session, policy.writeKind, () => confirm(effect.target)),
);

ServerConfirmNext<T, C> _verifying<T, C>(T target, int attempt) => StepNext(
  ConfirmVerifying<T, C>(target, attempt),
  [ConfirmVerify(target, attempt)],
);

ServerConfirmNext<T, C> _answered<T, C>(
  ServerConfirmPolicy<T> policy,
  T target,
  int attempt,
  GatedWrite<ExchangeWrite<C>> answer,
) => switch (answer) {
  GateRefused(refusal: WriteGateUnsettled(:final entry))
      when policy.matches(entry, target) =>
    _verifying(target, attempt),
  GateRefused(:final refusal) => StepNext(
    ConfirmWriteRefused<T, C>(target, attempt, refusal),
  ),
  GateAdmitted(result: WriteDone(:final value)) => StepNext(
    ConfirmConfirmed<T, C>(value),
  ),
  GateAdmitted(result: WriteRefused(:final reason)) => StepNext(
    ConfirmFailed<T, C>(target, attempt, WriteProblemRefused(reason)),
  ),
  GateAdmitted(result: WriteNotSent(:final reason)) => StepNext(
    ConfirmFailed<T, C>(target, attempt, WriteProblemNotSent(reason)),
  ),
  GateAdmitted(result: WriteOutcomeUnknown()) => _verifying(target, attempt),
  GateAdmitted(result: WriteSessionRejected()) => StepNext(
    ConfirmSessionEnded<T, C>(),
  ),
};

ServerConfirmNext<T, C> _checked<T, C>(
  T target,
  int attempt,
  ConfirmCheck<C> check,
) => switch (check) {
  ConfirmSeenApplied(:final confirmed) => StepNext(
    ConfirmConfirmed<T, C>(confirmed),
  ),
  ConfirmSeenNotApplied() => StepNext(
    ConfirmFailed<T, C>(target, attempt, const WriteProblemNotApplied()),
  ),
  ConfirmCheckFailed(:final problem) => StepNext(
    ConfirmUnverified<T, C>(target, attempt, problem),
  ),
  ConfirmCheckSessionRejected() => StepNext(ConfirmSessionEnded<T, C>()),
};

ServerConfirmNext<T, C> transitionServerConfirm<T, C>(
  ServerConfirmPolicy<T> policy,
  ServerConfirmState<T, C> state,
  ServerConfirmEvent<T, C> event,
) => switch ((state, event)) {
  (
    ConfirmConfirming(:final target, :final attempt),
    ConfirmAnswered(attempt: final answered, :final answer),
  )
      when answered == attempt =>
    _answered(policy, target, attempt, answer),
  (
    ConfirmConfirming(),
    ConfirmAnswered() ||
        ConfirmVerified() ||
        ConfirmCommitPressed() ||
        ConfirmRetryPressed() ||
        ConfirmBackPressed(),
  ) =>
    StepNext.stay(state),

  (ConfirmWriteRefused(:final target, :final attempt), ConfirmRetryPressed()) =>
    StepNext(ConfirmConfirming<T, C>(target, attempt + 1), [
      ConfirmSend(target, attempt + 1),
    ]),
  (ConfirmFailed(:final target, :final attempt), ConfirmCommitPressed()) =>
    StepNext(ConfirmConfirming<T, C>(target, attempt + 1), [
      ConfirmSend(target, attempt + 1),
    ]),
  (
    ConfirmWriteRefused() || ConfirmFailed() || ConfirmUnverified(),
    ConfirmBackPressed(),
  ) =>
    StepNext(ConfirmLeft<T, C>()),
  (
    ConfirmWriteRefused(),
    ConfirmAnswered() || ConfirmVerified() || ConfirmCommitPressed(),
  ) =>
    StepNext.stay(state),
  (
    ConfirmFailed(),
    ConfirmAnswered() || ConfirmVerified() || ConfirmRetryPressed(),
  ) =>
    StepNext.stay(state),

  (
    ConfirmVerifying(:final target, :final attempt),
    ConfirmVerified(attempt: final answered, :final check),
  )
      when answered == attempt =>
    _checked(target, attempt, check),
  (
    ConfirmVerifying(),
    ConfirmAnswered() ||
        ConfirmVerified() ||
        ConfirmCommitPressed() ||
        ConfirmRetryPressed() ||
        ConfirmBackPressed(),
  ) =>
    StepNext.stay(state),

  (ConfirmUnverified(:final target, :final attempt), ConfirmRetryPressed()) =>
    _verifying(target, attempt),
  (
    ConfirmUnverified(),
    ConfirmAnswered() || ConfirmVerified() || ConfirmCommitPressed(),
  ) =>
    StepNext.stay(state),

  (
    ConfirmConfirmed() || ConfirmSessionEnded() || ConfirmLeft(),
    ConfirmAnswered() ||
        ConfirmVerified() ||
        ConfirmCommitPressed() ||
        ConfirmRetryPressed() ||
        ConfirmBackPressed(),
  ) =>
    StepNext.stay(state),
};
