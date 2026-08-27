import 'package:decimal/decimal.dart';

const _satsPerBitcoin = 100000000;

BigInt orderSwapAmountToSats(String value) {
  final amount = Decimal.parse(value);
  final scaled = amount * Decimal.fromInt(_satsPerBitcoin);
  final sats = scaled.toBigInt();
  if (scaled != Decimal.fromBigInt(sats)) {
    throw const FormatException('Swap amount exceeds eight decimals');
  }
  return sats;
}

String orderSwapSatsToAmount(BigInt sats) {
  if (sats <= BigInt.zero) {
    throw ArgumentError.value(sats, 'sats', 'Amount must be positive');
  }
  final whole = sats ~/ BigInt.from(_satsPerBitcoin);
  final fraction = (sats % BigInt.from(_satsPerBitcoin))
      .toString()
      .padLeft(8, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole.toString() : '$whole.$fraction';
}
