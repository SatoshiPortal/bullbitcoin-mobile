import 'package:bull_swap/src/domain/swap_network.dart';
import 'package:meta/meta.dart';

@immutable
class CreatedSwap {
  final String providerId;
  final String swapId;
  final SwapEnvironment environment;
  final SwapNetwork inNetwork;
  final SwapNetwork outNetwork;
  final BigInt payinAmountSat;
  final BigInt payoutAmountSat;
  final String? payinAddress;
  final String? payinInvoice;
  final String? payoutAddress;
  final DateTime? expiresAt;

  const CreatedSwap({
    required this.providerId,
    required this.swapId,
    required this.environment,
    required this.inNetwork,
    required this.outNetwork,
    required this.payinAmountSat,
    required this.payoutAmountSat,
    this.payinAddress,
    this.payinInvoice,
    this.payoutAddress,
    this.expiresAt,
  });
}
