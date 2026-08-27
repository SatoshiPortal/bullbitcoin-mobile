import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';

class OrderSwapQuote {
  final BigInt inAmountSat;
  final BigInt outAmountSat;
  final OrderSwapNetwork inNetwork;
  final OrderSwapNetwork outNetwork;
  final String inCurrency;
  final String outCurrency;
  final int feeBasisPoints;
  final List<String> warnings;

  OrderSwapQuote({
    required this.inAmountSat,
    required this.outAmountSat,
    required this.inNetwork,
    required this.outNetwork,
    required this.inCurrency,
    required this.outCurrency,
    required this.feeBasisPoints,
    required this.warnings,
  }) {
    if (inAmountSat <= BigInt.zero || outAmountSat <= BigInt.zero) {
      throw ArgumentError('Swap quote amounts must be positive');
    }
    if (inNetwork == outNetwork) {
      throw ArgumentError('Swap quote networks must differ');
    }
  }
}
