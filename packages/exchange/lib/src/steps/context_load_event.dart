import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';

@immutable
sealed class ContextLoadEvent<C> {
  const ContextLoadEvent();
}

/// The load of [attempt] answered [read].
final class ContextLoaded<C> extends ContextLoadEvent<C> {
  final int attempt;
  final Result<C, ExchangeReadFailure> read;

  const ContextLoaded(this.attempt, this.read);
}

final class ContextRetryPressed<C> extends ContextLoadEvent<C> {
  const ContextRetryPressed();
}
