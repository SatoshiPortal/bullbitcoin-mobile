import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The host app initializes the bindings; these vectors run without one.
  setUpAll(BullSdk.init);

  final validBolt11s = [TestValue.bolt11Uppercase, TestValue.bolt11Lowercase];

  group('Bolt11', () {
    for (final invoice in validBolt11s) {
      test('parses $invoice', () async {
        final result = await Satoshifier.parse(invoice);
        expect(result, isA<Bolt11>());
      });
    }
  });
}
