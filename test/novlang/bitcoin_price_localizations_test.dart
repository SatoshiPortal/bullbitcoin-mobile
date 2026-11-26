import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_bitcoin_price_localizations.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novlang/novlang.dart';

void main() {
  test(
    'price display retains catalogue and Apple wording in every locale',
    () async {
      expect(
        BitcoinPriceLocalizations.supportedLocales,
        unorderedEquals(AppLocalizations.supportedLocales),
      );
      for (final locale in BitcoinPriceLocalizations.supportedLocales) {
        final app = await AppLocalizations.delegate.load(locale);
        final price = await BitcoinPriceLocalizations.delegate.load(locale);
        final appleApp = await const NovlangAppLocalizationsDelegate(
          NovlangPolicy.apple,
        ).load(locale);
        final applePrice = await const NovlangBitcoinPriceLocalizationsDelegate(
          NovlangPolicy.apple,
        ).load(locale);
        expect(
          price.bitcoinPriceExchangeRateUnavailable,
          app.bitcoinPriceExchangeRateUnavailable,
          reason: locale.toLanguageTag(),
        );
        expect(
          applePrice.bitcoinPriceExchangeRateUnavailable,
          appleApp.bitcoinPriceExchangeRateUnavailable,
          reason: locale.toLanguageTag(),
        );
      }
    },
  );
}
