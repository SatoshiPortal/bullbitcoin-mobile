import 'receive_failure.dart';

import 'package:primitives/primitives.dart';

/// The user's fiat intent at the quote used to obtain the exact payable sats.
final class ReceiveAmountConversion {
  final String enteredText;
  final String currencyCode;
  final double rate;
  final DateTime quotedAt;
  final Sats sats;

  ReceiveAmountConversion({
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

  static ReceiveFailure? validateQuantity(BigInt? sats) =>
      sats != null && sats > Sats.maxBitcoinSupply
      ? ReceiveAmountAboveProtocolLimitFailure(
          limitAmountSat: Sats.maxBitcoinSupply.toInt(),
        )
      : null;

  static ReceiveAmountConversion? fromEdit({
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
    return ReceiveAmountConversion(
      enteredText: text,
      currencyCode: currencyCode,
      rate: rate,
      quotedAt: quotedAt,
      sats: Sats(sats),
    );
  }
}
