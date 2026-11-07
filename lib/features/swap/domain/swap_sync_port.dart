import 'package:bb_mobile/features/swap/domain/entities/order_swap_polling.dart';

/// Requests a refresh through the foreground scheduler without owning its queue.
abstract interface class SwapSyncPort {
  Future<OrderSwapPollingAttempt> request();
}
