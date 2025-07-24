import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:intl/intl.dart';

class FormatAmount {
  static String sats(int satsAmount) {
    final currencyFormatter = NumberFormat.currency(
      name: 'sats',
      decimalDigits: 0,
      customPattern: '#,##0 ¤',
    );
    return currencyFormatter.format(satsAmount);
  }

  static String btc(double btcAmount) {
    const maxDecimals = 8;
    if (btcAmount >= 0.1 || btcAmount == 0.0) {
      // Format without trailing zero's with a maximum of 8 if the amount is
      // bigger or equal to 0.1 BTC. Also 0 should be formatted without trailing
      // zero's.
      final amountFormatter = NumberFormat('0.${'#' * maxDecimals}');
      final formattedAmount = amountFormatter.format(btcAmount);
      final amountWithCurrencyCode = '$formattedAmount ${BitcoinUnit.btc.code}';

      return amountWithCurrencyCode;
    } else {
      // Keep all decimal digits for lower amounts
      final currencyFormatter = NumberFormat.currency(
        name: 'BTC',
        decimalDigits: maxDecimals,
        customPattern: '#,##0.00000000 ¤',
      );
      final formatted = currencyFormatter.format(btcAmount);
      return formatted;
    }
  }

  static String fiat(
    double fiat,
    String currencyCode, {
    bool simpleFormat = false,
  }) {
    final currencyFormatter =
        simpleFormat
            ? NumberFormat.simpleCurrency(name: currencyCode)
            : NumberFormat.currency(
              name: currencyCode,
              customPattern: '#,##0.00 ¤',
            );

    return currencyFormatter.format(fiat);
  }
}
