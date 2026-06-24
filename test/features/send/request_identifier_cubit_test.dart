import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RequestIdentifierCubit', () {
    test(
      'maps an invalid pasted request to a sanitized SendFailure and does not '
      'redirect',
      () async {
        // Given
        final cubit = RequestIdentifierCubit();
        cubit.updateRawRequest('this is definitely not a payment request');

        // When
        await cubit.validatePaymentRequest();

        // Then
        expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
        expect(cubit.state.failure, isA<SendInvalidPaymentRequestGenericFailure>());
        expect(cubit.state.redirect, isNull);

        await cubit.close();
      },
    );

    test('clears the failure when the user edits the request', () async {
      // Given
      final cubit = RequestIdentifierCubit();
      cubit.updateRawRequest('not-a-request');
      await cubit.validatePaymentRequest();
      expect(cubit.state.failure, isNotNull);

      // When
      cubit.updateRawRequest('still-typing');

      // Then
      expect(cubit.state.failure, isNull);

      await cubit.close();
    });
  });
}
