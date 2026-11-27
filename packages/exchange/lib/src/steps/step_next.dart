import 'package:meta/meta.dart';

import '../domain/exchange_failure.dart';

import 'package:primitives/primitives.dart';

/// What a step's transition answers: the next [state] and the [effects] the
/// bloc starts on entering it. A stay returns the same state instance with no
/// effects, so a bloc emits only when the state changed.
@immutable
final class StepNext<S, F> {
  final S state;
  final List<F> effects;

  const StepNext(this.state, [this.effects = const []]);

  const StepNext.stay(this.state) : effects = const [];

  @override
  bool operator ==(Object other) {
    if (other is! StepNext ||
        other.state != state ||
        other.effects.length != effects.length) {
      return false;
    }
    for (var i = 0; i < effects.length; i++) {
      if (other.effects[i] != effects[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(state, Object.hashAll(effects));

  @override
  String toString() => 'StepNext($state, $effects)';
}

/// Why a write a step sent did not take effect. Shown on the step; the step
/// decides whether it may be sent again.
@immutable
sealed class WriteProblem {
  const WriteProblem();
}

/// The exchange refused the write.
final class WriteProblemRefused extends WriteProblem {
  final ExchangeRefusal reason;

  const WriteProblemRefused(this.reason);

  @override
  bool operator ==(Object other) =>
      other is WriteProblemRefused && other.reason == reason;

  @override
  int get hashCode => Object.hash(WriteProblemRefused, reason);
}

/// The write never left the app.
final class WriteProblemNotSent extends WriteProblem {
  final ExchangeNotSentReason reason;

  const WriteProblemNotSent(this.reason);

  @override
  bool operator ==(Object other) =>
      other is WriteProblemNotSent && other.reason == reason;

  @override
  int get hashCode => Object.hash(WriteProblemNotSent, reason);
}

/// The outcome was unknown, and a re-read showed it did not take effect.
final class WriteProblemNotApplied extends WriteProblem {
  const WriteProblemNotApplied();

  @override
  bool operator ==(Object other) => other is WriteProblemNotApplied;

  @override
  int get hashCode => (WriteProblemNotApplied).hashCode;
}

/// Why a read a step needs gave no value. A rejected session is not here: it
/// ends the flow.
@immutable
sealed class ReadProblem {
  const ReadProblem();

  /// The problem of a read that gave no value, or null for [Ok] and
  /// [ExchangeSessionRejectedFailure], which the caller handles.
  static ReadProblem? of<T>(Result<T, ExchangeReadFailure> read) =>
      switch (read) {
        Ok() || Err(failure: ExchangeSessionRejectedFailure()) => null,
        Err(failure: ExchangeMissingFailure()) => const ReadProblemMissing(),
        Err(failure: ExchangeUnreachableFailure(:final isNetwork)) =>
          ReadProblemUnreachable(isNetwork: isNetwork),
        Err(failure: ExchangeMalformedFailure()) =>
          const ReadProblemMalformed(),
      };
}

final class ReadProblemMissing extends ReadProblem {
  const ReadProblemMissing();

  @override
  bool operator ==(Object other) => other is ReadProblemMissing;

  @override
  int get hashCode => (ReadProblemMissing).hashCode;
}

final class ReadProblemUnreachable extends ReadProblem {
  final bool isNetwork;

  const ReadProblemUnreachable({required this.isNetwork});

  @override
  bool operator ==(Object other) =>
      other is ReadProblemUnreachable && other.isNetwork == isNetwork;

  @override
  int get hashCode => Object.hash(ReadProblemUnreachable, isNetwork);
}

final class ReadProblemMalformed extends ReadProblem {
  const ReadProblemMalformed();

  @override
  bool operator ==(Object other) => other is ReadProblemMalformed;

  @override
  int get hashCode => (ReadProblemMalformed).hashCode;
}
