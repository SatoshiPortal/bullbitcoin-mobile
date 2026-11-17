import 'package:primitives/primitives.dart';

/// Validate startup before test registration, where matchers cannot run.
/// Failure details stay at their existing logging boundary.
void requireSuccessfulBullInitialization(Result<void, Failure> result) {
  if (result is! Ok<void, Failure>) {
    throw StateError('Bull.init failed');
  }
}
