import 'order_swap_record.dart';
import '../swap_failure.dart';

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
