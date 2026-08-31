import 'package:bull_swap/src/domain/swap_network.dart';
import 'package:meta/meta.dart';

@immutable
class SwapQuote {
  final String providerId;
  final SwapNetwork inNetwork;
  final SwapNetwork outNetwork;
  final BigInt payinAmountSat;
  final BigInt payoutAmountSat;
  final BigInt feesSat;

  const SwapQuote({
    required this.providerId,
    required this.inNetwork,
    required this.outNetwork,
    required this.payinAmountSat,
    required this.payoutAmountSat,
    required this.feesSat,
  });
}
