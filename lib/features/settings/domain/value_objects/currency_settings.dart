import 'package:bb_mobile/features/settings/domain/primitives/bitcoin_unit.dart';
import 'package:bb_mobile/features/settings/domain/primitives/fiat_currency.dart';
import 'package:meta/meta.dart';

@immutable
class CurrencySettings {
  final FiatCurrency fiatCurrency;
  final BitcoinUnit bitcoinUnit;

  const CurrencySettings({
    required this.fiatCurrency,
    required this.bitcoinUnit,
  });

  // Note: Normally, value objects have dedicated update methods with validation.
  // However, for settings with simple enum/primitive values and no free-text input,
  // a simple copyWith is sufficient and avoids unnecessary boilerplate.
  CurrencySettings copyWith({
    FiatCurrency? fiatCurrency,
    BitcoinUnit? bitcoinUnit,
  }) {
    return CurrencySettings(
      fiatCurrency: fiatCurrency ?? this.fiatCurrency,
      bitcoinUnit: bitcoinUnit ?? this.bitcoinUnit,
    );
  }
}
