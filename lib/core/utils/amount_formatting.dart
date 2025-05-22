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
    final amountFormatter = NumberFormat('0.${'#' * maxDecimals}');
    final formattedAmount = amountFormatter.format(btcAmount);
    final amountWithCurrencyCode = '$formattedAmount ${BitcoinUnit.btc.code}';

    return amountWithCurrencyCode;
  }

  static String fiat(double fiat, String currencyCode) {
    final currencyFormatter = NumberFormat.currency(
      name: currencyCode,
      customPattern: '#,##0.00 ¤',
    );
    return currencyFormatter.format(fiat);
  }
}
