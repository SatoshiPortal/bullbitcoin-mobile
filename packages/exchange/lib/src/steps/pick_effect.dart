import 'package:meta/meta.dart';

import 'pick_event.dart';

@immutable
sealed class PickEffect<O> {
  const PickEffect();
}

/// Look [option] up; answer [PickResolved] for it.
final class PickResolve<O> extends PickEffect<O> {
  final O option;

  const PickResolve(this.option);

  @override
  bool operator ==(Object other) =>
      other is PickResolve && other.option == option;

  @override
  int get hashCode => Object.hash(PickResolve, option);

  @override
  String toString() => 'PickResolve($option)';
}

/// Validate [text] with the rail it parses as (C4's `BitcoinRail`); answer
/// [PickValidated] for it.
final class PickValidate<O> extends PickEffect<O> {
  final String text;

  const PickValidate(this.text);

  @override
  bool operator ==(Object other) => other is PickValidate && other.text == text;

  @override
  int get hashCode => Object.hash(PickValidate, text);

  @override
  String toString() => 'PickValidate("$text")';
}
