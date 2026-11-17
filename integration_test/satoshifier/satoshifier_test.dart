import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
