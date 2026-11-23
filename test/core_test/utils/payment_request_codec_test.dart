import 'package:satoshifier/payment_request.dart';
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:rust_bindings/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Sdk extends Mock implements BullSdkApi {}

// Bitcoin addresses and PSBTs are read by sync's codecs. LWK refuses every
// string here as a Liquid address, as the real binding does for them.
void main() {
  const address = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
  const psbt =
      'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
      'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
      'MzMzMzMzMzMzMzMzMzMzMzMAAA==';
  final sdk = _Sdk();

  setUpAll(() => BullSdk.initMock(api: sdk));
  tearDownAll(BullSdk.dispose);
  setUp(() {
    when(
      () => sdk.lwkApiTypesAddressValidate(
        addressString: any(named: 'addressString'),
      ),
    ).thenThrow(const lwk.LwkError(msg: 'not a Liquid address'));
  });

  test('a mainnet address reads in its canonical form', () async {
    final result = await PaymentRequest.parse(address.toUpperCase());
    expect(result, isA<BitcoinPaymentRequest>());
    final bitcoin = result as BitcoinPaymentRequest;
    expect(bitcoin.address, address);
    expect(bitcoin.isTestnet, isFalse);
  });

  test('a mainnet address with a bad checksum is refused', () async {
    final corrupted = '${address.substring(0, address.length - 1)}p';
    await expectLater(
      PaymentRequest.parse(corrupted),
      throwsA('Invalid payment request'),
    );
    await expectLater(
      PaymentRequest.parse('bitcoin:$corrupted'),
      throwsA('Invalid payment URI'),
    );
  });

  test('a PSBT is recognized and kept as the parser serializes it', () async {
    final result = await PaymentRequest.parse(psbt);
    expect(result, isA<PsbtPaymentRequest>());
    expect((result as PsbtPaymentRequest).psbt, psbt);
  });

  test('a truncated PSBT is not a payment request', () async {
    await expectLater(
      PaymentRequest.parse(psbt.substring(0, 40)),
      throwsA('Invalid payment request'),
    );
  });
}
