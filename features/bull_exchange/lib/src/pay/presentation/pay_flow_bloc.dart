import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/pay_flow.dart';
import 'package:bull_exchange/src/pay/domain/usecases/create_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/usecases/load_pay_context_usecase.dart';
import 'package:bull_exchange/src/pay/domain/usecases/refresh_pay_order_usecase.dart';
import 'package:bull_exchange/src/payin/outcome_watch_runner.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/spend_options_runner.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell of [transitionPayFlow]: applies events one at a time, emits the
/// new state and runs each effect through its use case with the flow's
/// session. Every answer carries the attempt, order id or ticket that asked
/// for it; the machine drops stale ones.
class PayFlowBloc extends Bloc<PayFlowEvent, PayFlowState> {
  PayFlowBloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
    required LoadPayContextUsecase loadContext,
    required GetMarketRateUsecase getMarketRate,
    required CreatePayOrderUsecase createOrder,
    required FindCreatedOrderUsecase findCreatedOrder,
    required RefreshPayOrderUsecase refreshOrder,
    required GetOrderUsecase getOrder,
    required PayoutRequirementsUsecases requirements,
    required PayinUsecases payin,
    required SpendOptionsUsecases spendOptions,
  }) : this._(
         payFlowStart(session),
         session,
         accessChanges,
         loadContext,
         getMarketRate,
         createOrder,
         findCreatedOrder,
         refreshOrder,
         getOrder,
         requirements,
         payin,
         spendOptions,
       );

  PayFlowBloc._(
    PayFlowNext start,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    this._loadContext,
    this._getMarketRate,
    this._createOrder,
    this._findCreatedOrder,
    this._refreshOrder,
    GetOrderUsecase getOrder,
    PayoutRequirementsUsecases requirements,
    PayinUsecases payin,
    SpendOptionsUsecases spendOptions,
  ) : super(start.state) {
    on<PayFlowEvent>(_onEvent, transformer: sequential());
    final session = _session;
    if (session != null) {
      _requirements = PayoutRequirementsRunner(requirements, session, (event) {
        if (!isClosed) add(PayRequirementsChanged(event));
      });
      _payin = PayinRunner(payin, session, (event) {
        if (!isClosed) add(PayPayinChanged(event));
      });
      _spend = SpendOptionsRunner(spendOptions, session, (event) {
        if (!isClosed) add(PaySpendChanged(event));
      });
      _receipt = OutcomeWatchRunner(
        (orderId) => getOrder.execute(session, orderId),
        (event) {
          if (!isClosed) add(PayReceiptChanged(event));
        },
      );
    }
    _access = accessChanges.listen((access) {
      if (!isClosed) add(PaySessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  /// The session the flow opened with; null runs nothing (the flow starts
  /// ended).
  final ExchangeSession? _session;
  final LoadPayContextUsecase _loadContext;
  final GetMarketRateUsecase _getMarketRate;
  final CreatePayOrderUsecase _createOrder;
  final FindCreatedOrderUsecase _findCreatedOrder;
  final RefreshPayOrderUsecase _refreshOrder;
  PayoutRequirementsRunner? _requirements;
  PayinRunner? _payin;
  SpendOptionsRunner? _spend;
  OutcomeWatchRunner<Order>? _receipt;
  late final StreamSubscription<ExchangeAccess> _access;
  final Map<int, DateTime> _sentAt = {};
  final Map<String, Timer> _quoteTimers = {};

  void _onEvent(PayFlowEvent event, Emitter<PayFlowState> emit) {
    final next = transitionPayFlow(state, event);
    if (identical(next.state, state) && next.effects.isEmpty) return;
    if (!identical(next.state, state)) emit(next.state);
    _run(next.effects);
  }

  void _run(List<PayFlowEffect> effects) {
    final session = _session;
    if (session == null) return;
    for (final effect in effects) {
      switch (effect) {
        case PayLoadContext(:final attempt):
          _answer(
            _loadContext
                .execute(session)
                .then((r) => PayContextLoaded(attempt, r)),
          );
        case PayReloadForDetour():
          _answer(_loadContext.execute(session).then(PayDetourLoaded.new));
        case PayFetchRate(:final market):
          _answer(
            _getMarketRate
                .execute(session, market)
                .then((r) => PayAmountChanged(AmountRateArrived(market, r))),
          );
        case PayRequirementsEffect(:final effect):
          _requirements?.run([effect]);
        case PayOrderEffect(:final effect):
          _order(session, effect);
        case PayPayinEffect(:final effect):
          _payin?.run([effect]);
        case PaySpendEffect(:final effect):
          _spend?.run([effect]);
        case PayReceiptEffect(:final effect):
          _receipt?.run(effect);
      }
    }
  }

  Order? get _quotedOrder => switch (state) {
    PayOrdering(order: OrderQuoted(:final quoted)) => quoted.order,
    PayLoading() ||
    PayRecipient() ||
    PayRequirements() ||
    PayAmount() ||
    PaySource() ||
    PayOrdering() ||
    PayPaying() ||
    PayDone() ||
    PaySessionEnded() ||
    PayClosed() => null,
  };

  void _order(ExchangeSession session, OrderStepEffect<PayRequest> effect) {
    switch (effect) {
      case final OrderSendCreate<PayRequest> send:
        _sentAt[send.attempt] = clock.now();
        _answer(_createOrder.execute(session, send).then(PayOrderChanged.new));
      case OrderFindCreated(:final request, :final attempt):
        _answer(
          _findCreatedOrder
              .execute<Order>(
                session,
                request.journal,
                _sentAt[attempt] ?? clock.now(),
              )
              .then((r) => PayOrderChanged(OrderFindAnswered(attempt, r))),
        );
      case OrderStartLockTimer(:final orderId):
        // The quote holds until the order's payment deadline.
        final deadline = _quotedOrder?.confirmationDeadline;
        if (deadline == null) break;
        final left = deadline.difference(clock.now());
        _arm(
          orderId,
          left.isNegative ? Duration.zero : left,
          () => OrderLockDue<PayRequest, Order>(orderId),
        );
      case OrderRefresh(:final orderId):
        final order = switch (state) {
          PayOrdering(order: OrderQuoted(:final quoted)) => quoted.order,
          PayPaying(:final quoted) => quoted.order,
          PayLoading() ||
          PayRecipient() ||
          PayRequirements() ||
          PayAmount() ||
          PaySource() ||
          PayOrdering() ||
          PayDone() ||
          PaySessionEnded() ||
          PayClosed() => null,
        };
        if (order == null || order.orderId != orderId) break;
        _answer(
          _refreshOrder
              .execute(session, order.orderId)
              .then((r) => PayOrderChanged(OrderRefreshed(orderId, r))),
        );
      case OrderScheduleRefreshRetry(:final orderId):
        _arm(
          orderId,
          const Duration(seconds: 5),
          () => OrderRetryDue<PayRequest, Order>(orderId),
        );
      case OrderStopTimers(:final orderId):
        _quoteTimers.remove(orderId)?.cancel();
      // Nothing to release: an unpaid order lapses at its deadline.
      case OrderRelease():
        break;
    }
  }

  void _arm(
    String orderId,
    Duration after,
    OrderStepEvent<PayRequest, Order> Function() event,
  ) {
    _quoteTimers.remove(orderId)?.cancel();
    _quoteTimers[orderId] = Timer(after, () {
      _quoteTimers.remove(orderId);
      if (!isClosed) add(PayOrderChanged(event()));
    });
  }

  void _answer(Future<PayFlowEvent> answer) {
    unawaited(
      answer.then((event) {
        if (!isClosed) add(event);
      }),
    );
  }

  @override
  Future<void> close() async {
    _requirements?.close();
    _payin?.close();
    _spend?.close();
    _receipt?.close();
    for (final timer in _quoteTimers.values) {
      timer.cancel();
    }
    _quoteTimers.clear();
    await _access.cancel();
    return super.close();
  }
}
