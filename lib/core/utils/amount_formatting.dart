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

  /// Format a fractional satoshi count for preview display (rate × vsize
  /// products etc.). Shows up to 2 decimals, drops trailing zeros, and
  /// kills IEEE 754 noise like `78.96000000000001` → `78.96`. The actual
  /// broadcast fee is always an integer sat — this is a preview format.
  static String satsApprox(num satsAmount) {
    return NumberFormat('#,##0.##').format(satsAmount);
  }

  /// Space-grouped satoshi digits, e.g. `99 000 000`. No unit and locale-
  /// independent: the surrounding localized string supplies the " sats" unit.
  /// Differs from [sats] on purpose: [sats] bundles a comma-grouped number and
  /// the unit for general (non-SP) use; the SP screens carry the unit in their
  /// own localized strings, so this returns the bare grouped number.
  static String satsGrouped(int satsAmount) =>
      NumberFormat('#,##0').format(satsAmount).replaceAll(',', ' ');

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
    final currencyFormatter = simpleFormat
        ? NumberFormat.simpleCurrency(name: currencyCode)
        : NumberFormat.currency(
            name: currencyCode,
            customPattern: '#,##0.00 ¤',
          );

    return currencyFormatter.format(fiat);
  }
}
