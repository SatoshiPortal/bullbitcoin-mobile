import 'package:flutter_test/flutter_test.dart' show fail;
import 'package:primitives/primitives.dart';

/// Validate startup before test registration, where matchers cannot run.
/// Failure details stay at their existing logging boundary.
void requireSuccessfulBullInitialization(Result<void, Failure> result) {
  if (result is! Ok<void, Failure>) {
    throw StateError('Bull.init failed');
  }
}

T requireValue<T>(Result<T, Failure> result, String operation) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('$operation failed: ${failure.runtimeType}'),
    };
