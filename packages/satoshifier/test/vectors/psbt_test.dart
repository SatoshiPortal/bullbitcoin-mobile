import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The host app initializes the bindings; these vectors run without one.
  setUpAll(BullSdk.init);

  group('Psbt', () {
    test('handles valid PSBT format', () async {
      final result = await Satoshifier.parse(TestValue.psbtBase64);
      expect(result, isA<Psbt>());
    });
  });
}
