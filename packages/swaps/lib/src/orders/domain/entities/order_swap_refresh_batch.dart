import 'package:swaps/order_swaps.dart';

class OrderSwapRefreshBatch {
  final int pollableOrderCount;
  final List<OrderSwapRecord> refreshed;
  final List<SwapFailure> failures;

  const OrderSwapRefreshBatch({
    required this.pollableOrderCount,
    required this.refreshed,
    required this.failures,
  });
}
