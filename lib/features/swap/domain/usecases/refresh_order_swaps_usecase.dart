import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/apply_completed_order_swap_labels_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_pending_order_swaps_usecase.dart';

class RefreshOrderSwapsUsecase {
  final RefreshPendingOrderSwapsUsecase _refreshPending;
  final ApplyCompletedOrderSwapLabelsUsecase _applyCompletedLabels;
  Future<Result<OrderSwapRefreshBatch, SwapFailure>>? _activeRefresh;

  RefreshOrderSwapsUsecase(this._refreshPending, this._applyCompletedLabels);

  Future<Result<OrderSwapRefreshBatch, SwapFailure>> execute() {
    final activeRefresh = _activeRefresh;
    if (activeRefresh != null) return activeRefresh;

    final refresh = _execute();
    _activeRefresh = refresh;
    return refresh.whenComplete(() {
      if (identical(_activeRefresh, refresh)) _activeRefresh = null;
    });
  }

  Future<Result<OrderSwapRefreshBatch, SwapFailure>> _execute() async {
    final result = await _refreshPending.execute();
    if (result case Err()) return result;

    return switch (await _applyCompletedLabels.execute()) {
      Ok() => result,
      Err(:final failure) => Err(failure),
    };
  }
}
