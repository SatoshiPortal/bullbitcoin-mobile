import 'package:meta/meta.dart';

import '../domain/exchange_call_result.dart';
import 'step_next.dart';

/// Loads the typed context [C] a flow needs (composition §4.2). Its output is
/// the value of [ContextReady]; gates that read the summary take [C], so they
/// never run on a missing one. Each load is tagged with its [attempt].
@immutable
sealed class ContextLoadState<C> {
  const ContextLoadState();
}

final class ContextLoading<C> extends ContextLoadState<C> {
  final int attempt;

  const ContextLoading(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ContextLoading && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ContextLoading, attempt);

  @override
  String toString() => 'ContextLoading($attempt)';
}

final class ContextReady<C> extends ContextLoadState<C> {
  final C context;

  const ContextReady(this.context);

  @override
  bool operator ==(Object other) =>
      other is ContextReady && other.context == context;

  @override
  int get hashCode => Object.hash(ContextReady, context);

  @override
  String toString() => 'ContextReady($context)';
}

/// The load of [attempt] gave no context; Retry loads again.
final class ContextFailed<C> extends ContextLoadState<C> {
  final int attempt;
  final ReadProblem problem;

  const ContextFailed(this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is ContextFailed &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(ContextFailed, attempt, problem);

  @override
  String toString() => 'ContextFailed($attempt, $problem)';
}

/// The server rejected the session's key: the flow ends its session.
/// Terminal.
final class ContextSessionRejected<C> extends ContextLoadState<C> {
  const ContextSessionRejected();

  @override
  bool operator ==(Object other) => other is ContextSessionRejected;

  @override
  int get hashCode => (ContextSessionRejected).hashCode;
}

@immutable
sealed class ContextLoadEvent<C> {
  const ContextLoadEvent();
}

/// The load of [attempt] answered [read].
final class ContextLoaded<C> extends ContextLoadEvent<C> {
  final int attempt;
  final ExchangeRead<C> read;

  const ContextLoaded(this.attempt, this.read);
}

final class ContextRetryPressed<C> extends ContextLoadEvent<C> {
  const ContextRetryPressed();
}

@immutable
sealed class ContextLoadEffect {
  const ContextLoadEffect();
}

/// Load the context and answer [ContextLoaded] with [attempt].
final class ContextFetch extends ContextLoadEffect {
  final int attempt;

  const ContextFetch(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ContextFetch && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ContextFetch, attempt);

  @override
  String toString() => 'ContextFetch($attempt)';
}

StepNext<ContextLoadState<C>, ContextLoadEffect> contextLoadStart<C>() =>
    StepNext(ContextLoading<C>(1), const [ContextFetch(1)]);

StepNext<ContextLoadState<C>, ContextLoadEffect> transitionContextLoad<C>(
  ContextLoadState<C> state,
  ContextLoadEvent<C> event,
) => switch ((state, event)) {
  (
    ContextLoading(:final attempt),
    ContextLoaded(attempt: final answered, :final read),
  )
      when answered == attempt =>
    switch (read) {
      ReadGot(:final value) => StepNext(ContextReady<C>(value)),
      ReadSessionRejected() => StepNext(ContextSessionRejected<C>()),
      ReadMissing() || ReadUnreachable() || ReadMalformed() => StepNext(
        ContextFailed<C>(attempt, ReadProblem.of(read)!),
      ),
    },
  (ContextLoading(), ContextLoaded() || ContextRetryPressed()) => StepNext.stay(
    state,
  ),

  (ContextFailed(:final attempt), ContextRetryPressed()) => StepNext(
    ContextLoading<C>(attempt + 1),
    [ContextFetch(attempt + 1)],
  ),
  (ContextFailed(), ContextLoaded()) => StepNext.stay(state),

  (
    ContextReady() || ContextSessionRejected(),
    ContextLoaded() || ContextRetryPressed(),
  ) =>
    StepNext.stay(state),
};
