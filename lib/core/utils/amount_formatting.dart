import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bull_ui/bull_ui.dart' show BullNumberFormat;
import 'package:intl/intl.dart';

class FormatAmount {
  static String sats(int satsAmount) {
    return '${BullNumberFormat.decimal(satsAmount, maxDecimals: 0)} sats';
  }

  /// Format a fractional satoshi count for preview display (rate × vsize
  /// products etc.). Shows up to 2 decimals, drops trailing zeros, and
  /// kills IEEE 754 noise like `78.96000000000001` → `78.96`. The actual
  /// broadcast fee is always an integer sat — this is a preview format.
  static String satsApprox(num satsAmount) {
    return BullNumberFormat.decimal(satsAmount);
  }

  static String btc(double btcAmount) {
    const maxDecimals = 8;
    if (btcAmount >= 0.1 || btcAmount == 0.0) {
      // Format without trailing zero's with a maximum of 8 if the amount is
      // bigger or equal to 0.1 BTC. Also 0 should be formatted without trailing
      // zero's.
      final formattedAmount = BullNumberFormat.decimal(
        btcAmount,
        maxDecimals: maxDecimals,
        grouping: false,
      );
      return '$formattedAmount ${BitcoinUnit.btc.code}';
    } else {
      // Keep all decimal digits for lower amounts
      final formattedAmount = BullNumberFormat.decimal(
        btcAmount,
        minDecimals: maxDecimals,
        maxDecimals: maxDecimals,
      );
      return '$formattedAmount ${BitcoinUnit.btc.code}';
    }
  }

  static String fiat(
    double fiat,
    String currencyCode, {
    bool simpleFormat = false,
  }) {
    // Only read for the currency's own symbol and decimal count (e.g. 0 for
    // JPY); the digits themselves are written by [BullNumberFormat].
    final currency = simpleFormat
        ? NumberFormat.simpleCurrency(name: currencyCode)
        : NumberFormat.currency(name: currencyCode);
    final decimals = currency.decimalDigits ?? 2;
    if (!simpleFormat) {
      final formattedAmount = BullNumberFormat.decimal(
        fiat,
        minDecimals: decimals,
        maxDecimals: decimals,
      );
      return '$formattedAmount $currencyCode';
    }

    // The sign goes before the symbol: `-$0.50`, not `$-0.50`.
    final formattedAmount = BullNumberFormat.decimal(
      fiat.abs(),
      minDecimals: decimals,
      maxDecimals: decimals,
    );
    return '${fiat < 0 ? '-' : ''}${currency.currencySymbol}$formattedAmount';
  }
}
