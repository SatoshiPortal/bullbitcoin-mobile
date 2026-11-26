import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/cancel_all_limit_orders_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_active_limit_orders_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// Shell of [transitionLimitOrdersList]. Limit-order notifications and the
/// dashboard's refresh requests are events. The list reads the current
/// session's account; the cancel-all runs with the session the list opened
/// with ([session], null when signed out).
class LimitOrdersListBloc
    extends Bloc<LimitOrdersListEvent, LimitOrdersListState> {
  LimitOrdersListBloc({
    required this._session,
    required this._getActiveOrders,
    required this._cancelAllOrders,
    required Stream<Result<NotificationMessage, ExchangeFailure>> notifications,
    Stream<void>? refreshRequests,
  }) : super(limitOrdersListStart.state) {
    on<LimitOrdersListEvent>(_onEvent, transformer: sequential());
    _notifications = notifications
        .where(
          (event) =>
              event is Ok<NotificationMessage, ExchangeFailure> &&
              event.value.kind == NotificationMessageKind.limitOrder,
        )
        .listen((_) => _refresh());
    _refreshes = refreshRequests?.listen((_) => _refresh());
    _run(limitOrdersListStart.effects);
  }

  final ExchangeSession? _session;
  final GetActiveLimitOrdersUsecase _getActiveOrders;
  final CancelAllLimitOrdersUsecase _cancelAllOrders;
  late final StreamSubscription<Object?> _notifications;
  StreamSubscription<void>? _refreshes;

  void _refresh() {
    if (!isClosed) add(const ListRefreshRequested());
  }

  void _onEvent(
    LimitOrdersListEvent event,
    Emitter<LimitOrdersListState> emit,
  ) {
    final next = transitionLimitOrdersList(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<LimitOrdersListEffect> effects) {
    for (final effect in effects) {
      final Future<LimitOrdersListEvent> answer = switch (effect) {
        ListFetch(:final attempt) => _getActiveOrders.execute().then(
          (read) => ListLoaded(attempt, read),
        ),
        ListCancelAll(:final attempt) =>
          _cancelAllOrders
              .execute(_session)
              .then((answer) => ListCancelAllAnswered(attempt, answer)),
      };
      unawaited(
        answer.then((event) {
          if (!isClosed) add(event);
        }),
      );
    }
  }

  @override
  Future<void> close() async {
    await _notifications.cancel();
    await _refreshes?.cancel();
    return super.close();
  }
}
