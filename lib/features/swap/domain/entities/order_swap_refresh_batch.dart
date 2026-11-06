import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';

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
