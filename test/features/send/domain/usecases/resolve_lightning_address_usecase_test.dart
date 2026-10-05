import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_lightning_address_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const usecase = ResolveLightningAddressUsecase();

  group('ResolveLightningAddressUsecase', () {
    // The amount guard runs before any LNURL lookup, so these are the cases
    // that can be asserted without touching the network.
    for (final amountSat in [0, -1, -100000]) {
      test('refuses to resolve for an amount of $amountSat sats', () async {
        final result = await usecase.execute(
          lightningAddress: 'user@example.com',
          amountSat: amountSat,
        );

        switch (result) {
          case Ok():
            fail('an LN address cannot be resolved without a positive amount');
          case Err(:final failure):
            expect(failure, isA<SendInvoiceAmountRequiredFailure>());
        }
      });
    }

    test('the amount guard leaks nothing about the address', () async {
      final result = await usecase.execute(
        lightningAddress: 'someone-private@example.com',
        amountSat: 0,
      );

      final failure =
          (result as Err<Bolt11PaymentRequest, SendFailure>).failure;
      expect(
        failure.logMessage,
        anyOf(isNull, isNot(contains('someone-private'))),
        reason: 'the address must not travel in the failure',
      );
    });
  });
}
