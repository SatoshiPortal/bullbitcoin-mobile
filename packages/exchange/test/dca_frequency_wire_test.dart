import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/dca_frequency_wire.dart';
import 'package:exchange/src/data/unknown_server_value.dart';
import 'package:test/test.dart';

void main() {
  test('every frequency round-trips through its wire value', () {
    for (final frequency in DcaBuyFrequency.values) {
      expect(
        dcaFrequencyFromWire(DcaFrequencyWire.toWire(frequency).value),
        frequency,
      );
    }
  });

  test('reads any case, as the user summary did', () {
    expect(dcaFrequencyFromWire('weekly'), DcaBuyFrequency.weekly);
    expect(dcaFrequencyFromWire('Monthly'), DcaBuyFrequency.monthly);
  });

  test('a missing value is null and is not logged', () {
    expect(dcaFrequencyFromWire(null), isNull);
    expect(UnknownServerValues.report('DCA frequency', null), isTrue);
  });

  test('an unknown value is null and is logged once', () {
    expect(dcaFrequencyFromWire('YEARLY'), isNull);
    expect(UnknownServerValues.report('DCA frequency', 'YEARLY'), isFalse);
  });
}
