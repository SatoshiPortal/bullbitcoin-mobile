import 'package:primitives/primitives.dart' show BitcoinUnit;

typedef AmountDisplayPreferences = ({
  BitcoinUnit bitcoinUnit,
  bool hideAmounts,
  String currencyCode,
});

abstract interface class AmountDisplayPreferencesReader {
  /// An unavailable preference masks amounts until a valid value arrives.
  Stream<AmountDisplayPreferences?> watchDisplayPreferences();
}
