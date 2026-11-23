import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every recipient type is in the jurisdiction of its market', () {
    for (final type in RecipientType.values) {
      expect(
        type.jurisdiction,
        ExchangeCatalog.jurisdictionOf(type.currency),
        reason: type.name,
      );
      expect(type.currencyCode, type.currency.code, reason: type.name);
    }
  });

  test('every market has at least one recipient type', () {
    for (final market in ExchangeCatalog.markets) {
      expect(
        RecipientType.typesForCurrency(market.currency.code),
        isNotEmpty,
        reason: market.currency.code,
      );
    }
  });
}
