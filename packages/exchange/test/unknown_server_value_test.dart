import 'package:exchange/src/data/unknown_server_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each unknown value of a kind is reported once', () {
    expect(UnknownServerValues.report('test status A', 'NEW'), isTrue);
    expect(UnknownServerValues.report('test status A', 'NEW'), isFalse);
    expect(UnknownServerValues.report('test status A', 'OTHER'), isTrue);
    expect(UnknownServerValues.report('test status B', 'NEW'), isTrue);
  });

  test('a missing value is reported once per kind', () {
    expect(UnknownServerValues.report('test status C', null), isTrue);
    expect(UnknownServerValues.report('test status C', null), isFalse);
  });

  test(
    'long values are cut, so two long values with the same start are one',
    () {
      final start = 'X' * 40;
      expect(UnknownServerValues.report('test status D', '${start}1'), isTrue);
      expect(UnknownServerValues.report('test status D', '${start}2'), isFalse);
    },
  );
}
