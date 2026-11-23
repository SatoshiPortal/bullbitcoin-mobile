import 'package:address_view/payment_destination.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_purchase_binding.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  PaymentDestinationField payoutField(WalletAddressType type) =>
      exchangePurchaseHost(GetIt.asNewInstance()).payoutField(
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
