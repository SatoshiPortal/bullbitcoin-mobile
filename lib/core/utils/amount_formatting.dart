import 'package:intl/intl.dart';

class AmountFormatting {
  static String formatSats(int satsAmount) {
    final currencyFormatter = NumberFormat.currency(
      name: 'sats',
      decimalDigits: 0,
      customPattern: '#,##0 ¤',
    );
    return currencyFormatter.format(satsAmount);
  }

  static String formatBtc(double btcAmount) {
    NumberFormat currencyFormatter;
    String formatted;

    if (btcAmount >= 0.1) {
      currencyFormatter = NumberFormat.currency(
        name: 'BTC',
        decimalDigits: 8,
        customPattern: '#,##0.00 ¤',
      );
      formatted = currencyFormatter.format(btcAmount);
      formatted = formatted.replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
    } else {
      currencyFormatter = NumberFormat.currency(
        name: 'BTC',
        decimalDigits: 8,
        customPattern: '#,##0.00000000 ¤',
      );
      formatted = currencyFormatter.format(btcAmount);
    }

    return formatted;
  }

  static String formatFiat(double fiat, String currencyCode) {
    final currencyFormatter = NumberFormat.currency(
      name: currencyCode,
      customPattern: '#,##0.00 ¤',
    );
    return currencyFormatter.format(fiat);
  }
}
