import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// The failure an [Err] carries, typed by the [Result] itself, so a test can
/// read it without an `as` cast. An [Ok] fails the test instead.
F failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

/// The value an [Ok] carries; an [Err] fails the test, naming the failure.
T valueOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};
