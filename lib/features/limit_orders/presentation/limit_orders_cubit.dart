import 'dart:async';

import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/can_create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/cancel_all_limit_orders_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/list_active_limit_orders_usecase.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class LimitOrdersCubit extends Cubit<LimitOrdersState> {
  final ListActiveLimitOrdersUsecase _listActive;
  final CancelAllLimitOrdersUsecase _cancelAll;
  final CanCreateLimitOrderUsecase _canCreate;
  final ExchangeNotificationService _notifications;

  StreamSubscription<NotificationMessage>? _subscription;
  StreamSubscription<void>? _refreshSubscription;

  LimitOrdersCubit(
    this._listActive,
    this._cancelAll,
    this._canCreate,
    this._notifications, {
    Stream<void>? refreshRequests,
  }) : super(const LimitOrdersState()) {
    _subscription = _notifications.messageStream
        .where((message) => message.kind == NotificationMessageKind.limitOrder)
        .listen((_) => load());
    _refreshSubscription = refreshRequests?.listen((_) => load());
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await _listActive.execute();
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
    final result = await _cancelAll.execute();
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
