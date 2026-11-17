import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final valids = [
    TestValue.liquidAddressMain,
    TestValue.liquidAddressUppercase,
    TestValue.liquidCompatible,
  ];

  group('Liquid Addresses', () {
    for (var address in valids) {
      test('parses $address', () async {
        final result = await Satoshifier.parse(address);
        expect(result, isA<LiquidAddress>());
      });
    }
  });
}
