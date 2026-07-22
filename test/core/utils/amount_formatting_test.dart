import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormatAmount.satsGrouped', () {
    test('groups thousands with spaces', () {
      expect(FormatAmount.satsGrouped(99000000), '99 000 000');
      expect(FormatAmount.satsGrouped(1234), '1 234');
    });

    test('leaves sub-thousand amounts ungrouped', () {
      expect(FormatAmount.satsGrouped(0), '0');
      expect(FormatAmount.satsGrouped(999), '999');
    });

    test('keeps the negative sign', () {
      expect(FormatAmount.satsGrouped(-99000000), '-99 000 000');
      expect(FormatAmount.satsGrouped(-1234), '-1 234');
    });
  });
}
