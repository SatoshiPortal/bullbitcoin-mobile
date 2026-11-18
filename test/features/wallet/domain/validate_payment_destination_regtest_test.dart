import 'package:bb_mobile/features/wallet/domain/payment_destination.dart';
import 'package:bb_mobile/features/wallet/domain/validate_payment_destination_usecase.dart';
import 'package:bull_sdk/bull_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, Ok;
import 'package:sync/sync.dart' show parseBitcoinAddress, liquidAddressNetwork;

void main() {
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);
  test('native codecs accept the three regtest fixtures', () async {
    expect(
      parseBitcoinAddress(
        'bcrt1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3lgth6c',
        BitcoinNetwork.regtest,
      ),
      isA<Ok>(),
    );
    for (final address in [
      'ert1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg38u7fyc',
      'el1qqfumuen7l8wthtz45p3ftn58pvrs9xlumvkuu2xet8egzkcklqtesg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyqsscuw9qrf4q',
    ]) {
      final network = await liquidAddressNetwork(address);
      expect(network, isA<Ok>());
      switch (network) {
        case Ok(:final value):
          expect(value, LiquidNetwork.regtest);
        default:
          fail('Native codec refused the regtest fixture');
      }
    }
  });
  const validate = ValidatePaymentDestinationUsecase();
  for (final fixture in [
    (
      'mainnet control',
      'bc1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3h8ffkz',
      PaymentDestinationType.bitcoin,
    ),
    (
      'testnet control',
      'tb1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3apj6d3',
      PaymentDestinationType.bitcoin,
    ),
    (
      'regtest Bitcoin',
      'bcrt1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3lgth6c',
      PaymentDestinationType.bitcoin,
    ),
    (
      'regtest Liquid',
      'ert1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg38u7fyc',
      PaymentDestinationType.liquid,
    ),
    (
      'regtest confidential Liquid',
      'el1qqfumuen7l8wthtz45p3ftn58pvrs9xlumvkuu2xet8egzkcklqtesg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyqsscuw9qrf4q',
      PaymentDestinationType.liquid,
    ),
  ]) {
    test(
      '${fixture.$1} is recognized by the external transfer field validator',
      () async {
        final destination = await validate.execute(
          fixture.$2,
          acceptedTypes: {fixture.$3},
        );
        expect(destination, isNotNull);
        expect(destination?.address, fixture.$2);
        expect(destination?.type, fixture.$3);
      },
    );
  }
}
