import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The host app initializes the bindings; these vectors run without one.
  setUpAll(BullSdk.init);

  final validLnurls = [
    TestValue.lnurlUppercase,
    TestValue.lnurlLowercase,
    TestValue.lnAddressUppercase,
    TestValue.lnAddressLowercase,
  ];

  group('LNURL', () {
    test('parses all', () async {
      for (final lnurl in validLnurls) {
        final result = await Satoshifier.parse(lnurl);
        expect(result, isNotNull);
      }
    });

    test('strips the lightning scheme from an uppercase LNURL', () async {
      final lnurl = TestValue.lnurlUppercase;
      final result = await Satoshifier.parse('lightning:$lnurl');

      expect(result, isA<Lnurl>());
      expect((result as Lnurl).address, lnurl);
    });
  });
}
