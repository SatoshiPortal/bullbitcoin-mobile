import '../entities/order.dart';
import 'jurisdiction.dart';
import 'kyc_policy.dart';
import 'market.dart';

/// The one place that says which markets the exchange has.
abstract final class ExchangeCatalog {
  /// Canada limited verification: 999.99 CAD per transaction (and 3000 CAD
  /// per day, left to the server).
  static const cadLimitedPerTransactionCap = 999.99;

  static const _fullOnly = KycPolicy({KycGroup.identityVerified: null});

  static const usd = Market(
    currency: FiatCurrency.usd,
    jurisdiction: Jurisdiction.costaRica,
    kyc: _fullOnly,
  );
  static const cad = Market(
    currency: FiatCurrency.cad,
    jurisdiction: Jurisdiction.canada,
    kyc: KycPolicy({
      KycGroup.identityVerified: null,
      KycGroup.canadaLight: null,
      KycGroup.limited: cadLimitedPerTransactionCap,
    }),
  );
  static const crc = Market(
    currency: FiatCurrency.crc,
    jurisdiction: Jurisdiction.costaRica,
    kyc: KycPolicy({
      KycGroup.identityVerified: null,
      KycGroup.limited: null,
      KycGroup.sinpeVerified: null,
    }),
  );
  static const eur = Market(
    currency: FiatCurrency.eur,
    jurisdiction: Jurisdiction.europe,
    kyc: _fullOnly,
  );
  static const mxn = Market(
    currency: FiatCurrency.mxn,
    jurisdiction: Jurisdiction.mexico,
    kyc: _fullOnly,
  );
  static const ars = Market(
    currency: FiatCurrency.ars,
    jurisdiction: Jurisdiction.argentina,
    kyc: KycPolicy({
      KycGroup.identityVerified: null,
      KycGroup.limited: null,
      KycGroup.missionary: null,
    }),
  );
  static const cop = Market(
    currency: FiatCurrency.cop,
    jurisdiction: Jurisdiction.colombia,
    kyc: _fullOnly,
  );

  /// Stand-in where a flow needs a market but has none (no currency on the
  /// account, nothing loaded yet) and its state cannot say so yet. The flow
  /// rebuilds remove every caller; do not add new ones.
  static const Market legacyNoMarketFallback = cad;

  /// [parse], with an absent or unknown code read as
  /// [legacyNoMarketFallback]. Same rule: the flow rebuilds remove it.
  static FiatCurrency legacyCurrencyOrFallback(String? raw) =>
      switch (raw == null ? null : parse(raw)) {
        KnownCurrency(:final currency) => currency,
        UnknownCurrency() || null => legacyNoMarketFallback.currency,
      };

  /// Every market, in the order the currency pickers show them.
  static const List<Market> markets = [usd, cad, crc, eur, mxn, ars, cop];

  /// Reads a currency code from the server or storage. A code this build has
  /// no market for is [UnknownCurrency], never an exception or a default.
  static ParsedCurrency parse(String raw) {
    final code = raw.trim().toUpperCase();
    for (final market in markets) {
      if (market.currency.code == code) return KnownCurrency(market);
    }
    return UnknownCurrency(raw);
  }

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

/// A currency code read at the boundary: a market of the catalog, or a code
/// this build does not know.
sealed class ParsedCurrency {
  const ParsedCurrency();
}

final class KnownCurrency extends ParsedCurrency {
  final Market market;

  const KnownCurrency(this.market);

  FiatCurrency get currency => market.currency;

  @override
  bool operator ==(Object other) =>
      other is KnownCurrency && other.market == market;

  @override
  int get hashCode => market.hashCode;
}

final class UnknownCurrency extends ParsedCurrency {
  final String raw;

  const UnknownCurrency(this.raw);

  @override
  bool operator ==(Object other) =>
      other is UnknownCurrency && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;
}
