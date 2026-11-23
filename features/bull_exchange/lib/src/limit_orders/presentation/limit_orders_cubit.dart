import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/can_create_limit_order_usecase.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_orders_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class LimitOrdersCubit extends Cubit<LimitOrdersState> {
  final ExchangeLimitOrders _orders;
  final CanCreateLimitOrderUsecase _canCreate;
  final Stream<Result<NotificationMessage, ExchangeFailure>> _notifications;

  StreamSubscription<Result<NotificationMessage, ExchangeFailure>>?
  _subscription;
  StreamSubscription<void>? _refreshSubscription;

  LimitOrdersCubit(
    this._orders,
    this._canCreate,
    this._notifications, {
    Stream<void>? refreshRequests,
  }) : super(const LimitOrdersState()) {
    _subscription = _notifications
        .where(
          (event) =>
              event is Ok<NotificationMessage, ExchangeFailure> &&
              event.value.kind == NotificationMessageKind.limitOrder,
        )
        .listen((_) => load());
    _refreshSubscription = refreshRequests?.listen((_) => load());
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await _orders.listActive();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            orders: value,
            canCreate: _canCreate.execute(value),
            isLoading: false,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  Future<void> cancelAll() async {
    emit(state.copyWith(isCancellingAll: true, clearFailure: true));
    final result = await _orders.cancelAll();
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            orders: const [],
            canCreate: _canCreate.execute(const []),
            isCancellingAll: false,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isCancellingAll: false, failure: failure));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _refreshSubscription?.cancel();
    return super.close();
  }
}
