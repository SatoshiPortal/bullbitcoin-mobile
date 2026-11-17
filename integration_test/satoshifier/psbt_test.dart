import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Psbt', () {
    test('handles valid PSBT format', () async {
      final result = await Satoshifier.parse(TestValue.psbtBase64);
      expect(result, isA<Psbt>());
    });
  });
}
