import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../integration_test/initialization_result.dart';

class _InitializationFailure extends Failure {
  const _InitializationFailure() : super('diagnostic contents must not escape');
}

void main() {
  // Deliberately run outside a test: the original matcher failed here.
  requireSuccessfulBullInitialization(const Ok<void, Failure>(null));

  test('accepts successful startup before test registration', () {
    requireSuccessfulBullInitialization(const Ok<void, Failure>(null));
  });

  test('failed startup throws a fixed error without failure details', () {
    expect(
      () => requireSuccessfulBullInitialization(
        const Err<void, Failure>(_InitializationFailure()),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Bull.init failed',
        ),
      ),
    );
  });
}
