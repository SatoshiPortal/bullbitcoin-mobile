import 'package:bb_mobile/features/swap/data/models/order_swap_quote_model.dart';
import 'package:bb_mobile/features/swap/data/order_swap_amount_codec.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_quote.dart';
import 'package:decimal/decimal.dart';

extension OrderSwapQuoteMapper on OrderSwapQuoteModel {
  OrderSwapQuote toEntity({
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
  }) {
    final basisPoints = feePercents.fold<int>(0, (total, percent) {
      final scaled = Decimal.parse(percent) * Decimal.fromInt(100);
      if (scaled != Decimal.fromBigInt(scaled.toBigInt())) {
        throw const FormatException(
          'Fee percent exceeds basis-point precision',
        );
      }
      return total + scaled.toBigInt().toInt();
    });
    return OrderSwapQuote(
      inAmountSat: orderSwapAmountToSats(inAmount),
      outAmountSat: orderSwapAmountToSats(outAmount),
      inNetwork: inNetwork,
      outNetwork: outNetwork,
      inCurrency: inCurrency,
      outCurrency: outCurrency,
      feeBasisPoints: basisPoints,
      warnings: List.unmodifiable(warnings),
    );
  }
}
