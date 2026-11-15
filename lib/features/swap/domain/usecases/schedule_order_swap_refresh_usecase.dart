import 'package:bb_mobile/features/swap/domain/entities/order_swap_polling.dart';
import 'package:bb_mobile/features/swap/domain/swap_sync_port.dart';

class ScheduleOrderSwapRefreshUsecase {
  final SwapSyncPort _sync;

  const ScheduleOrderSwapRefreshUsecase(this._sync);

  Future<OrderSwapPollingAttempt> execute() => _sync.request();
}
