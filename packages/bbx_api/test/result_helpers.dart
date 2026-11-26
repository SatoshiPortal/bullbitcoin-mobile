import 'package:bbx_api/bbx_api.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

/// The value of [result], failing the test on a failure.
T valueOf<T>(Result<T, BbxFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Unexpected failure: $failure'),
};

/// The failure of [result], failing the test on a value.
BbxFailure failureOf<T>(Result<T, BbxFailure> result) => switch (result) {
  Ok(:final value) => fail('Unexpected value: $value'),
  Err(:final failure) => failure,
};

/// The failure of [call], failing the test when it succeeds.
Future<BbxFailure> failedCall<T>(Future<Result<T, BbxFailure>> call) async =>
    failureOf(await call);
