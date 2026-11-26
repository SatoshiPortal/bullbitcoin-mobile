import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_details_flow.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/cancel_limit_order_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_limit_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell of [transitionLimitDetails]: applies events one at a time, emits
/// the new state and runs each effect through its use case with the
/// details' session, each answer tagged with its attempt.
class LimitDetailsBloc extends Bloc<LimitDetailsEvent, LimitDetailsState> {
  LimitDetailsBloc({
    required ExchangeSession? session,
    required String orderId,
    required Stream<ExchangeAccess> accessChanges,
    required GetLimitOrderUsecase getOrder,
    required CancelLimitOrderUsecase cancelOrder,
  }) : this._(
         limitDetailsStart(session, orderId),
         session,
         accessChanges,
         getOrder,
         cancelOrder,
       );

  LimitDetailsBloc._(
    LimitDetailsNext start,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    this._getOrder,
    this._cancelOrder,
  ) : super(start.state) {
    on<LimitDetailsEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(DetailsSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  /// The session the details opened with; null runs nothing.
  final ExchangeSession? _session;
  final GetLimitOrderUsecase _getOrder;
  final CancelLimitOrderUsecase _cancelOrder;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(LimitDetailsEvent event, Emitter<LimitDetailsState> emit) {
    final next = transitionLimitDetails(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<LimitDetailsEffect> effects) {
    final session = _session;
    if (session == null) return;
    for (final effect in effects) {
      switch (effect) {
        case DetailsRead(:final orderId, :final attempt):
          _answer(
            _getOrder.execute(orderId).then((r) => DetailsLoaded(attempt, r)),
          );
        case DetailsCancelEffect(
          effect: CancelSend(:final orderId, :final attempt),
        ):
          _answer(
            _cancelOrder
                .execute(session, orderId)
                .then((a) => DetailsCancelChanged(CancelAnswered(attempt, a))),
          );
        case DetailsCancelEffect(
          effect: CancelRead(:final orderId, :final attempt),
        ):
          _answer(
            _getOrder
                .execute(orderId)
                .then((r) => DetailsCancelChanged(CancelChecked(attempt, r))),
          );
      }
    }
  }

  void _answer(Future<LimitDetailsEvent> answer) {
    unawaited(
      answer.then((event) {
        if (!isClosed) add(event);
      }),
    );
  }

  @override
  Future<void> close() async {
    await _access.cancel();
    return super.close();
  }
}
