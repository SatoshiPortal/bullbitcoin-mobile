import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '_values.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bip21', () {
    for (final uri in [
      TestValues.bip21BitcoinUriBasic,
      TestValues.bip21BitcoinSegwitLowercaseBasic,
      TestValues.bip21BitcoinSegwitUppercaseBasic,
      TestValues.bip21BitcoinLegacyBasic,
      TestValues.bip21BitcoinCompatibleBasic,

      TestValues.bip21BitcoinUriWithAmount,
      TestValues.bip21BitcoinSegwitLowercaseAmountOnly,
      TestValues.bip21BitcoinSegwitUppercaseAmountOnly,
      TestValues.bip21BitcoinLegacyAmountOnly,
      TestValues.bip21BitcoinCompatibleAmountOnly,

      TestValues.bip21BitcoinSegwitLowercaseLabelOnly,
      TestValues.bip21BitcoinSegwitUppercaseLabelOnly,
      TestValues.bip21BitcoinLegacyLabelOnly,
      TestValues.bip21BitcoinCompatibleLabelOnly,

      TestValues.bip21BitcoinSegwitLowercaseAmountLabel,
      TestValues.bip21BitcoinSegwitUppercaseAmountLabel,
      TestValues.bip21BitcoinLegacyAmountLabel,
      TestValues.bip21BitcoinCompatibleAmountLabel,

      TestValues.bip21BitcoinSegwitAmountLabelMessage,
      TestValues.bip21BitcoinSegwitAmountMessage,
      TestValues.bip21BitcoinSegwitLabelMessage,
      TestValues.bip21BitcoinSegwitMessageOnly,

      TestValues.bip21LiquidUriBasic,
      TestValues.bip21LiquidSegwitUppercaseBasic,
      TestValues.bip21LiquidSegwitLowercaseBasic,
      TestValues.bip21LiquidCompatibleBasic,

      TestValues.bip21LiquidSegwitUppercaseAmountOnly,
      TestValues.bip21LiquidSegwitLowercaseAmountOnly,
      TestValues.bip21LiquidCompatibleAmountOnly,

      TestValues.bip21LiquidSegwitUppercaseLabelOnly,
      TestValues.bip21LiquidSegwitLowercaseLabelOnly,
      TestValues.bip21LiquidCompatibleLabelOnly,

      TestValues.bip21LiquidSegwitUppercaseAmountLabel,
      TestValues.bip21LiquidSegwitLowercaseAmountLabel,
      TestValues.bip21LiquidCompatibleAmountLabel,

      TestValues.payjoinWithPercentEncoding,
      TestValues.payjoinWithoutPercentEncoding,

      TestValues.unifiedQrUppercase,
      TestValues.unifiedQrLowercase,
    ]) {
      test('parses $uri', () async {
        final result = await PaymentRequest.parse(uri);
        expect(result, isA<Bip21PaymentRequest>());
      });
    }
  });

  group('Bitcoin Addresses', () {
    for (final address in [
      TestValues.mainnetP2PKH,
      TestValues.mainnetP2SH,
      TestValues.mainnetBech32,
      TestValues.mainnetBech32Uppercase,
      TestValues.testnetP2PKH,
      TestValues.testnetP2SH,
      TestValues.testnetBech32,
    ]) {
      test('parses $address', () async {
        final result = await PaymentRequest.parse(address);
        expect(result, isA<BitcoinPaymentRequest>());
      });
    }
  });

  group('Bolt11', () {
    for (final invoice in [
      TestValues.bolt11Uppercase,
      TestValues.bolt11Lowercase,
    ]) {
      test('parses $invoice', () async {
        final result = await PaymentRequest.parse(invoice);
        expect(result, isA<Bolt11PaymentRequest>());
      });
    }
  });

  group('Liquid Addresses', () {
    for (final address in [
      TestValues.liquidAddressMain,
      TestValues.liquidAddressUppercase,
      TestValues.liquidCompatible,
    ]) {
      test('parses $address', () async {
        final result = await PaymentRequest.parse(address);
        expect(result, isA<LiquidPaymentRequest>());
      });
    }
  });

  group('LNURL', () {
    test('parses all', () async {
      for (final lnurl in [
        TestValues.lnurlUppercase,
        TestValues.lnurlLowercase,
        TestValues.lnAddressUppercase,
        TestValues.lnAddressLowercase,
      ]) {
        final result = await PaymentRequest.parse(lnurl);
        expect(result, isNotNull);
      }
    });
  });

  group('Psbt', () {
    for (final psbt in [TestValues.psbtBase64]) {
      test('handles valid PSBT format', () async {
        final result = await PaymentRequest.parse(psbt);
        expect(result, isA<PsbtPaymentRequest>());
      });
    }
  });
}
