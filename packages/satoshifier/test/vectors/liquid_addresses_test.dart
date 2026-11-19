import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The host app initializes the bindings; these vectors run without one.
  setUpAll(BullSdk.init);

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
