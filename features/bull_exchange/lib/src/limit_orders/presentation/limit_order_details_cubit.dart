import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_order_details_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class LimitOrderDetailsCubit extends Cubit<LimitOrderDetailsState> {
  final String _id;
  final ExchangeLimitOrders _orders;

  LimitOrderDetailsCubit(this._id, this._orders)
    : super(const LimitOrderDetailsState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await _orders.get(_id);
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
    final result = await _orders.cancel(_id);
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
