import 'package:meta/meta.dart';

enum SwapLifecycleStatus {
  pending,
  awaitingPayin,
  payinDetected,
  payoutInProgress,
  completed,
  refunded,
  expired,
  failed;

  bool get isTerminal => switch (this) {
    completed || refunded || expired || failed => true,
    _ => false,
  };
}

@immutable
class SwapStatusUpdate {
  final String swapId;
  final SwapLifecycleStatus status;
  final String? payinTxId;
  final String? payoutTxId;

  const SwapStatusUpdate({
    required this.swapId,
    required this.status,
    this.payinTxId,
    this.payoutTxId,
  });
}
