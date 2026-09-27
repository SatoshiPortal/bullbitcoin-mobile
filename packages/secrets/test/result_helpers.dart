import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// The value, or a test failure naming the failure's type.
T ok<T>(Result<T, SecretFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got ${failure.runtimeType}'),
};

/// The failure, or a test failure.
SecretFailure err<T>(Result<T, SecretFailure> result) => switch (result) {
  Err(:final failure) => failure,
  Ok(:final value) => fail('expected Err, got Ok($value)'),
};
