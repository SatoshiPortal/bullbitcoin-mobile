import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
