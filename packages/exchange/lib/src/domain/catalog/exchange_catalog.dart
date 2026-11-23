import '../entities/order.dart';
import 'jurisdiction.dart';
import 'market.dart';

/// The one place that says which markets the exchange has.
abstract final class ExchangeCatalog {
  static const usd = Market(
    currency: FiatCurrency.usd,
    jurisdiction: Jurisdiction.costaRica,
  );
  static const cad = Market(
    currency: FiatCurrency.cad,
    jurisdiction: Jurisdiction.canada,
  );
  static const crc = Market(
    currency: FiatCurrency.crc,
    jurisdiction: Jurisdiction.costaRica,
  );
  static const eur = Market(
    currency: FiatCurrency.eur,
    jurisdiction: Jurisdiction.europe,
  );
  static const mxn = Market(
    currency: FiatCurrency.mxn,
    jurisdiction: Jurisdiction.mexico,
  );
  static const ars = Market(
    currency: FiatCurrency.ars,
    jurisdiction: Jurisdiction.argentina,
  );
  static const cop = Market(
    currency: FiatCurrency.cop,
    jurisdiction: Jurisdiction.colombia,
  );

  /// Every market, in the order the currency pickers show them.
  static const List<Market> markets = [usd, cad, crc, eur, mxn, ars, cop];

  static Market market(FiatCurrency currency) => switch (currency) {
    FiatCurrency.usd => usd,
    FiatCurrency.cad => cad,
    FiatCurrency.crc => crc,
    FiatCurrency.eur => eur,
    FiatCurrency.mxn => mxn,
    FiatCurrency.ars => ars,
    FiatCurrency.cop => cop,
  };

  static Jurisdiction jurisdictionOf(FiatCurrency currency) =>
      market(currency).jurisdiction;

  static List<Market> marketsIn(Jurisdiction jurisdiction) => [
    for (final market in markets)
      if (market.jurisdiction == jurisdiction) market,
  ];
}
