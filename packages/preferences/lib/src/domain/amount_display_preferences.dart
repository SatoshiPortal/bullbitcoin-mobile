import 'package:primitives/primitives.dart' show BitcoinUnit, Result;

import 'preferences_failure.dart';

typedef AmountDisplayPreferences = ({
  BitcoinUnit bitcoinUnit,
  bool hideAmounts,
  String currencyCode,
});

abstract interface class AmountDisplayPreferencesReader {
  /// A failure masks amounts until a valid value arrives; observation continues.
  Stream<Result<AmountDisplayPreferences, PreferencesFailure>>
  watchDisplayPreferences();
}
