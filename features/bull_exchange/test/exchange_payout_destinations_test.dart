import 'package:address_view/payment_destination.dart';
import 'package:bull_exchange/src/exchange_payout_destinations.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaymentDestinationField payoutField(WalletAddressType type) =>
      exchangePurchasePayoutField(
        type: type,
        value: '',
        label: 'label',
        hint: 'hint',
        enabled: true,
        onChanged: (_) {},
        onValidated: (_) {},
      ) as PaymentDestinationField;

  test('lightning payout field accepts LNURL like the limit order base', () {
    expect(payoutField(WalletAddressType.lightning).allowLnurl, isTrue);
  });

  test('bitcoin payout field keeps accepting LNURL for purchases', () {
    expect(payoutField(WalletAddressType.bitcoin).allowLnurl, isTrue);
  });
}
