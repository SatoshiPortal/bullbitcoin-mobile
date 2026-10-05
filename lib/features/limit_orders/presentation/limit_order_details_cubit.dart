import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/cancel_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/get_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_order_details_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class LimitOrderDetailsCubit extends Cubit<LimitOrderDetailsState> {
  final String _id;
  final GetLimitOrderUsecase _getOrder;
  final CancelLimitOrderUsecase _cancelOrder;

  LimitOrderDetailsCubit(this._id, this._getOrder, this._cancelOrder)
    : super(const LimitOrderDetailsState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await _getOrder.execute(_id);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(order: value, isLoading: false));
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  Future<void> cancel() async {
    emit(state.copyWith(isCancelling: true, clearFailure: true));
    final result = await _cancelOrder.execute(_id);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(order: value, isCancelling: false, wasCancelled: true),
        );
      case Err(:final failure):
        emit(state.copyWith(isCancelling: false, failure: failure));
    }
  }
}
