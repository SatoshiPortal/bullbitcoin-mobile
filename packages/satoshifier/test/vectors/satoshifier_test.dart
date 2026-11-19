import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:satoshifier/satoshifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The host app initializes the bindings; these vectors run without one.
  setUpAll(BullSdk.init);

  group('Satoshifier', () {
    test('throws for empty string', () async {
      expect(() => Satoshifier.parse(''), throwsA(isA<String>()));
    });

    test('throws for whitespace only', () async {
      expect(() => Satoshifier.parse('   '), throwsA(isA<String>()));
    });

    test('throws for invalid input', () async {
      expect(() => Satoshifier.parse('invalid'), throwsA(isA<String>()));
    });
  });
}
