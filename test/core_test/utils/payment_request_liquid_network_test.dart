import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:bull_sdk/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Sdk extends Mock implements BullSdkApi {}

void main() {
  final sdk = _Sdk();
  // Public address derived from a synthetic script and blinding public key.
  const address =
      'el1qqfumuen7l8wthtz45p3ftn58pvrs9xlumvkuu2xet8egzkcklqtesg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyqsscuw9qrf4q';

  setUpAll(() => BullSdk.initMock(api: sdk));
  tearDownAll(BullSdk.dispose);

  test('does not classify a Liquid regtest address as mainnet', () async {
    when(() => sdk.lwkApiTypesAddressValidate(addressString: address))
        .thenAnswer((_) async => lwk.LiquidNetwork.regtest);

    await expectLater(
      PaymentRequest.parse(address),
      throwsA('Invalid payment request'),
    );
  });
}
