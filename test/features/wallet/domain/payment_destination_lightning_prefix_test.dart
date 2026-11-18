import 'package:bb_mobile/features/wallet/public/payment_destination.dart';
import 'package:bull_sdk/bull_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);
  for (final prefix in ['bcrt1', 'ert1', 'el1']) {
    for (final separator in ['@', '%40']) {
      for (final allowRegtest in [true, false]) {
        test(
          'Lightning $prefix$separator preserves policy $allowRegtest',
          () async {
            final raw = '${prefix}alice${separator}example.com';
            final destination = await const WalletPaymentDestinationFacade()
                .validate(
                  raw,
                  acceptedTypes: {PaymentDestinationType.lightningAddress},
                  allowRegtest: allowRegtest,
                );
            expect(destination, isNotNull);
            expect(destination?.raw, raw);
            expect(destination?.address, '${prefix}alice@example.com');
            expect(destination?.type, PaymentDestinationType.lightningAddress);
          },
        );
      }
    }
  }
}
