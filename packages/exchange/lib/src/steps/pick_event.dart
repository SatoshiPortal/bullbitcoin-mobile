import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';

@immutable
sealed class PickEvent<O, V> {
  const PickEvent();
}

final class PickChose<O, V> extends PickEvent<O, V> {
  final O option;

  const PickChose(this.option);
}

final class PickTyped<O, V> extends PickEvent<O, V> {
  final String text;

  const PickTyped(this.text);
}

/// The validation of [text] answered [result].
final class PickValidated<O, V> extends PickEvent<O, V> {
  final String text;
  final Result<V, ExchangeFailure> result;

  const PickValidated(this.text, this.result);
}

/// The lookup of [option] answered [result].
final class PickResolved<O, V> extends PickEvent<O, V> {
  final O option;
  final Result<V, ExchangeFailure> result;

  const PickResolved(this.option, this.result);
}

/// Back from the next step, or away from a lookup or validation.
final class PickBackPressed<O, V> extends PickEvent<O, V> {
  const PickBackPressed();
}
