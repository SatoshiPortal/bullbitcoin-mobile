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

/// The value a scoped result carries, whichever variant it is. Use it where the test is about the value; assert on the variant where the test is about the passphrase.
T anyScope<T>(Result<PassphraseScope<T>, SecretFailure> result) =>
    switch (ok(result)) {
      WholeSecret(:final value) => value,
      WordsOnly(:final value) => value,
    };

/// The value inside one scoped result, whichever variant. For tests that already asserted the variant.
T scoped<T>(PassphraseScope<T> scope) => switch (scope) {
  WholeSecret(:final value) => value,
  WordsOnly(:final value) => value,
};
