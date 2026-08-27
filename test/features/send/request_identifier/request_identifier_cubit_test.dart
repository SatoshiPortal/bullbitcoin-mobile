import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bitcoinAddress = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';

  test('redirects only after the scanned request has parsed', () async {
    final cubit = RequestIdentifierCubit();
    addTearDown(cubit.close);

    await cubit.onScanned(bitcoinAddress);

    expect(cubit.state.redirect, RequestIdentifierRedirect.toSend);
    expect(cubit.state.failure, isNull);
  });

  test('models an invalid request as a Send failure', () async {
    final cubit = RequestIdentifierCubit();
    addTearDown(cubit.close);
    cubit.updateRawRequest('not-a-payment-request');

    await cubit.validatePaymentRequest();

    expect(cubit.state.redirect, isNull);
    expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
  });
}
