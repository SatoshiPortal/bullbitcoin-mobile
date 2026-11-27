import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:bull_exchange/src/withdraw/domain/usecases/confirm_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/usecases/create_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/usecases/load_withdraw_context_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell of [WithdrawFlowState.next]: applies events one at a time, emits the
/// new state and runs each effect through its use case with the flow's
/// session. Every answer carries the attempt, ticket or market that asked
/// for it; the machine drops stale ones.
class WithdrawFlowBloc extends Bloc<WithdrawFlowEvent, WithdrawFlowState> {
  WithdrawFlowBloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
    required LoadWithdrawContextUsecase loadContext,
    required GetMarketRateUsecase getMarketRate,
    required CreateWithdrawOrderUsecase createOrder,
    required FindCreatedOrderUsecase findCreatedOrder,
    required ConfirmWithdrawOrderUsecase confirmOrder,
    required GetOrderUsecase getOrder,
    required PayoutRequirementsUsecases requirements,
  }) : this._(
         withdrawFlowStart(session),
         session,
         accessChanges,
         loadContext,
         getMarketRate,
         createOrder,
         findCreatedOrder,
         confirmOrder,
         getOrder,
         requirements,
       );

  WithdrawFlowBloc._(
    WithdrawFlowNext start,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    this._loadContext,
    this._getMarketRate,
    this._createOrder,
    this._findCreatedOrder,
    this._confirmOrder,
    this._getOrder,
    PayoutRequirementsUsecases requirements,
  ) : super(start.state) {
    on<WithdrawFlowEvent>(_onEvent, transformer: sequential());
    final session = _session;
    if (session != null) {
      _requirements = PayoutRequirementsRunner(requirements, session, (event) {
        if (!isClosed) add(WithdrawRequirementsChanged(event));
      });
    }
    _access = accessChanges.listen((access) {
      if (!isClosed) add(WithdrawSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  /// The session the flow opened with; null runs nothing (the flow starts
  /// ended).
  final ExchangeSession? _session;
  final LoadWithdrawContextUsecase _loadContext;
  final GetMarketRateUsecase _getMarketRate;
  final CreateWithdrawOrderUsecase _createOrder;
  final FindCreatedOrderUsecase _findCreatedOrder;
  final ConfirmWithdrawOrderUsecase _confirmOrder;
  final GetOrderUsecase _getOrder;
  PayoutRequirementsRunner? _requirements;
  late final StreamSubscription<ExchangeAccess> _access;

  /// When each create attempt was sent: the re-read after an unknown outcome
  /// matches orders created around it.
  final Map<int, DateTime> _sentAt = {};

  void _onEvent(WithdrawFlowEvent event, Emitter<WithdrawFlowState> emit) {
    final next = state.next(event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<WithdrawFlowEffect> effects) {
    final session = _session;
    if (session == null) return;
    for (final effect in effects) {
      switch (effect) {
        case WithdrawLoadContext(:final attempt):
          _answer(
            _loadContext
                .execute(session)
                .then((r) => WithdrawContextLoaded(attempt, r)),
          );
        case WithdrawFetchRate(:final market):
          _answer(
            _getMarketRate
                .execute(session, market)
                .then(
                  (r) => WithdrawAmountChanged(AmountRateArrived(market, r)),
                ),
          );
        case WithdrawRequirementsEffect(:final effect):
          _requirements?.run([effect]);
        case WithdrawOrderEffect(:final effect):
          _order(session, effect);
        case WithdrawConfirmEffect(:final effect):
          _confirm(session, effect);
      }
    }
  }

  void _order(
    ExchangeSession session,
    OrderStepEffect<WithdrawRequest> effect,
  ) {
    switch (effect) {
      case final OrderSendCreate<WithdrawRequest> send:
        _sentAt[send.attempt] = clock.now();
        _answer(
          _createOrder.execute(session, send).then(WithdrawOrderChanged.new),
        );
      case OrderFindCreated(:final request, :final attempt):
        _answer(
          _findCreatedOrder
              .execute<WithdrawOrder>(
                session,
                request.journal,
                _sentAt[attempt] ?? clock.now(),
              )
              .then((r) => WithdrawOrderChanged(OrderFindAnswered(attempt, r))),
        );
      // A withdrawal order has no quote lock (withdrawOrderPolicy): the
      // step never asks for timers, refreshes or a release.
      case OrderStartLockTimer() ||
          OrderRefresh() ||
          OrderScheduleRefreshRetry() ||
          OrderStopTimers() ||
          OrderRelease():
        break;
    }
  }

  void _confirm(
    ExchangeSession session,
    ServerConfirmEffect<WithdrawConfirmTarget> effect,
  ) {
    switch (effect) {
      case final ConfirmSend<WithdrawConfirmTarget> send:
        _answer(
          _confirmOrder.execute(session, send).then(WithdrawConfirmChanged.new),
        );
      case ConfirmVerify(:final target, :final attempt):
        _answer(
          _getOrder
              .execute(session, target.order.orderId)
              .then(
                (read) => WithdrawConfirmChanged(
                  ConfirmVerified(attempt, withdrawConfirmCheck(read)),
                ),
              ),
        );
    }
  }

  void _answer(Future<WithdrawFlowEvent> answer) {
    unawaited(
      answer.then((event) {
        if (!isClosed) add(event);
      }),
    );
  }

  @override
  Future<void> close() async {
    _requirements?.close();
    await _access.cancel();
    return super.close();
  }
}
