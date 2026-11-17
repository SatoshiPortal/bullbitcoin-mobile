import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // TODO: Add test for liquidtestnet: URIs

  final valids = [
    TestValue.bip21BitcoinUriBasic,
    TestValue.bip21BitcoinSegwitLowercaseBasic,
    TestValue.bip21BitcoinSegwitUppercaseBasic,
    TestValue.bip21BitcoinLegacyBasic,
    TestValue.bip21BitcoinCompatibleBasic,

    TestValue.bip21BitcoinUriWithAmount,
    TestValue.bip21BitcoinSegwitLowercaseAmountOnly,
    TestValue.bip21BitcoinSegwitUppercaseAmountOnly,
    TestValue.bip21BitcoinLegacyAmountOnly,
    TestValue.bip21BitcoinCompatibleAmountOnly,

    TestValue.bip21BitcoinSegwitLowercaseLabelOnly,
    TestValue.bip21BitcoinSegwitUppercaseLabelOnly,
    TestValue.bip21BitcoinLegacyLabelOnly,
    TestValue.bip21BitcoinCompatibleLabelOnly,

    TestValue.bip21BitcoinSegwitLowercaseAmountLabel,
    TestValue.bip21BitcoinSegwitUppercaseAmountLabel,
    TestValue.bip21BitcoinLegacyAmountLabel,
    TestValue.bip21BitcoinCompatibleAmountLabel,

    TestValue.bip21BitcoinSegwitAmountLabelMessage,
    TestValue.bip21BitcoinSegwitAmountMessage,
    TestValue.bip21BitcoinSegwitLabelMessage,
    TestValue.bip21BitcoinSegwitMessageOnly,

    TestValue.bip21LiquidUriBasic,
    TestValue.bip21LiquidSegwitUppercaseBasic,
    TestValue.bip21LiquidSegwitLowercaseBasic,
    TestValue.bip21LiquidCompatibleBasic,

    TestValue.bip21LiquidSegwitUppercaseAmountOnly,
    TestValue.bip21LiquidSegwitLowercaseAmountOnly,
    TestValue.bip21LiquidCompatibleAmountOnly,

    TestValue.bip21LiquidSegwitUppercaseLabelOnly,
    TestValue.bip21LiquidSegwitLowercaseLabelOnly,
    TestValue.bip21LiquidCompatibleLabelOnly,

    TestValue.bip21LiquidSegwitUppercaseAmountLabel,
    TestValue.bip21LiquidSegwitLowercaseAmountLabel,
    TestValue.bip21LiquidCompatibleAmountLabel,

    TestValue.payjoinWithPercentEncoding,
    TestValue.payjoinWithoutPercentEncoding,

    TestValue.unifiedQrUppercase,
    TestValue.unifiedQrLowercase,
  ];

  group('Bip21', () {
    for (final uri in valids) {
      test('parses $uri', () async {
        final result = await Bip21Parser.parse(uri);
        expect(result, isA<Bip21>());
      });
    }
  });
}
