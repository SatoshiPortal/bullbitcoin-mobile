import 'send_failure.dart';

import 'package:primitives/primitives.dart';

/// The user's fiat intent at the quote used to obtain the exact payable sats.
final class SendAmountConversion {
  final String enteredText;
  final String currencyCode;
  final double rate;
  final DateTime quotedAt;
  final Sats sats;

  SendAmountConversion({
    required this.enteredText,
    required this.currencyCode,
    required this.rate,
    required this.quotedAt,
    required this.sats,
  }) {
    if (Sats.tryFromFiat(enteredText, rate) != sats) {
      throw ArgumentError('The conversion must match the quoted fiat intent');
    }
  }

  /// Whether this fiat intent produced exactly [amountSat]; an amount edited
  /// through another path since then makes the intent stale.
  bool producedAmount(int amountSat) => sats.value == BigInt.from(amountSat);

  static SendFailure? validateQuantity(BigInt? sats) =>
      sats != null && sats > Sats.maxBitcoinSupply
      ? SendAmountOutOfBoundsFailure(maximumSat: Sats.maxBitcoinSupply)
      : null;

  static SendAmountConversion? fromEdit({
    required BigInt? sats,
    required String currencyCode,
    required String text,
    required double? rate,
    required DateTime? quotedAt,
  }) {
    if (sats == null ||
        validateQuantity(sats) != null ||
        rate == null ||
        quotedAt == null ||
        Sats.tryFromFiat(text, rate)?.value != sats) {
      return null;
    }
    return SendAmountConversion(
      enteredText: text,
      currencyCode: currencyCode,
      rate: rate,
      quotedAt: quotedAt,
      sats: Sats(sats),
    );
  }
}
