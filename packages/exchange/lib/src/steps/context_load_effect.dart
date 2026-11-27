import 'package:meta/meta.dart';

import 'context_load_event.dart';

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
