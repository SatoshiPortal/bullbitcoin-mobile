import 'package:bb_mobile/core/primitives/payment_network.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/swap_failure_to_send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves the provider retry delay for rate limits', () {
    final failure = mapSwapFailureToSendFailure(
      const SwapRateLimitedFailure(retryAfter: Duration(seconds: 45)),
    );

    expect(failure, isA<SendRateLimitedFailure>());
    expect(
      (failure as SendRateLimitedFailure).retryAfter,
      const Duration(seconds: 45),
    );
  });

  test('maps a missing payment route to a dedicated failure', () {
    final failure = mapSwapFailureToSendFailure(
      const SwapNoPaymentOptionFailure(
        inNetwork: PaymentNetwork.bitcoin,
        outNetwork: PaymentNetwork.lightning,
        logMessage: 'no route',
      ),
    );

    expect(failure, isA<SendSwapRouteUnavailableFailure>());
    expect(
      (failure as SendSwapRouteUnavailableFailure).inNetwork,
      PaymentNetwork.bitcoin,
    );
    expect(failure.outNetwork, PaymentNetwork.lightning);
  });
}
