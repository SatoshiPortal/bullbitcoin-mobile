import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('preserves persisted names, ordering, codes and decimals', () {
    expect(BitcoinUnit.values, [BitcoinUnit.btc, BitcoinUnit.sats]);
    expect(BitcoinUnit.values.map((unit) => unit.name), ['btc', 'sats']);
    expect(BitcoinUnit.values.map((unit) => unit.code), ['BTC', 'sats']);
    expect(BitcoinUnit.values.map((unit) => unit.decimals), [8, 0]);
  });

  test('round trips names and codes through the existing factories', () {
    for (final unit in BitcoinUnit.values) {
      expect(BitcoinUnit.fromName(unit.name), same(unit));
      expect(BitcoinUnit.fromCode(unit.code), same(unit));
    }
  });

  test('keeps case-sensitive invalid-name and invalid-code failures', () {
    expect(() => BitcoinUnit.fromName('BTC'), throwsStateError);
    expect(() => BitcoinUnit.fromName('unknown'), throwsStateError);
    expect(() => BitcoinUnit.fromCode('btc'), throwsStateError);
    expect(() => BitcoinUnit.fromCode('unknown'), throwsStateError);
  });
}
