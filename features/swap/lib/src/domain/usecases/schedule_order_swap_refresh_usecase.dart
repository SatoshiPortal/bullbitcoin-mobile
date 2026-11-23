import 'package:swaps/order_swaps.dart';
import 'package:swap_feature/src/domain/swap_sync_port.dart';

class ScheduleOrderSwapRefreshUsecase {
  final SwapSyncPort Function() _sync;

  const ScheduleOrderSwapRefreshUsecase(this._sync);

  Future<OrderSwapPollingAttempt> execute() => _sync().request();
}
