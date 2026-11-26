import 'package:swaps/order_swaps.dart';

/// Requests a refresh through the foreground scheduler without owning its queue.
abstract interface class SwapSyncPort {
  Future<OrderSwapPollingAttempt> request();
}
