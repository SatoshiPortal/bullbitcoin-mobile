import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/features/buy/domain/validate_buy_destination_usecase.dart';
import 'package:bb_mobile/features/default_wallets/domain/validate_default_wallet_destination_usecase.dart';
import 'package:bb_mobile/features/wallet/public/payment_destination.dart';
import 'package:bull_sdk/bull_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);
  const fixtures = [
    (WalletAddressType.bitcoin, 'bcrt1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3lgth6c'),
    (WalletAddressType.liquid, 'ert1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg38u7fyc'),
    (
      WalletAddressType.liquid,
      'el1qqfumuen7l8wthtz45p3ftn58pvrs9xlumvkuu2xet8egzkcklqtesg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyqsscuw9qrf4q',
    ),
  ];
  test('exchange policies keep refusing regtest payouts', () async {
    final buy = ValidateBuyDestinationUsecase();
    final defaults = ValidateDefaultWalletDestinationUsecase();
    for (final fixture in fixtures) {
      expect(await buy.execute(fixture.$2), isNull);
      expect(await defaults.execute(fixture.$1, fixture.$2), isNull);
    }
  });
  test('Lightning-only fields keep refusing on-chain regtest', () async {
    for (final fixture in fixtures) {
      expect(
        await const WalletPaymentDestinationFacade().validate(
          fixture.$2,
          acceptedTypes: {PaymentDestinationType.lightningAddress},
        ),
        isNull,
      );
    }
  });
  test('native address validation refuses checksum corruption and mixed case', () async {
    for (final fixture in fixtures) {
      final address = fixture.$2;
      for (final invalid in [
        '${address.substring(0, address.length - 1)}${address.endsWith('q') ? 'p' : 'q'}',
        '${address[0].toUpperCase()}${address.substring(1)}',
      ]) {
        expect(
          await const WalletPaymentDestinationFacade().validate(
            invalid,
            acceptedTypes: {
              PaymentDestinationType.bitcoin,
              PaymentDestinationType.liquid,
            },
          ),
          isNull,
        );
      }
    }
  });
}
