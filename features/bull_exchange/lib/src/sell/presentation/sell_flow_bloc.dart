import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/spend_options_runner.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:bull_exchange/src/sell/domain/sell_flow.dart';
import 'package:bull_exchange/src/sell/domain/usecases/create_sell_order_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/load_sell_context_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/refresh_sell_order_usecase.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell of [transitionSellFlow]: applies events one at a time, emits the
/// new state and runs each effect through its use case with the flow's
/// session. Every answer carries the attempt, order id or ticket that asked
/// for it; the machine drops stale ones.
class SellFlowBloc extends Bloc<SellFlowEvent, SellFlowState> {
  SellFlowBloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
    required LoadSellContextUsecase loadContext,
    required GetMarketRateUsecase getMarketRate,
    required CreateSellOrderUsecase createOrder,
    required FindCreatedOrderUsecase findCreatedOrder,
    required RefreshSellOrderUsecase refreshOrder,
    required PayoutRequirementsUsecases requirements,
    required PayinUsecases payin,
    required SpendOptionsUsecases spendOptions,
  }) : this._(
         sellFlowStart(session),
         session,
         accessChanges,
         loadContext,
         getMarketRate,
         createOrder,
         findCreatedOrder,
         refreshOrder,
         requirements,
         payin,
         spendOptions,
       );

  SellFlowBloc._(
    SellFlowNext start,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    this._loadContext,
    this._getMarketRate,
    this._createOrder,
    this._findCreatedOrder,
    this._refreshOrder,
    PayoutRequirementsUsecases requirements,
    PayinUsecases payin,
    SpendOptionsUsecases spendOptions,
  ) : super(start.state) {
    on<SellFlowEvent>(_onEvent, transformer: sequential());
    final session = _session;
    if (session != null) {
      _requirements = PayoutRequirementsRunner(requirements, session, (event) {
        if (!isClosed) add(SellRequirementsChanged(event));
      });
      _payin = PayinRunner(payin, session, (event) {
        if (!isClosed) add(SellPayinChanged(event));
      });
      _spend = SpendOptionsRunner(spendOptions, session, (event) {
        if (!isClosed) add(SellSpendChanged(event));
      });
    }
    _access = accessChanges.listen((access) {
      if (!isClosed) add(SellSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  /// The session the flow opened with; null runs nothing (the flow starts
  /// ended).
  final ExchangeSession? _session;
  final LoadSellContextUsecase _loadContext;
  final GetMarketRateUsecase _getMarketRate;
  final CreateSellOrderUsecase _createOrder;
  final FindCreatedOrderUsecase _findCreatedOrder;
  final RefreshSellOrderUsecase _refreshOrder;
  PayoutRequirementsRunner? _requirements;
  PayinRunner? _payin;
  SpendOptionsRunner? _spend;
  late final StreamSubscription<ExchangeAccess> _access;
  final Map<int, DateTime> _sentAt = {};
  final Map<String, Timer> _quoteTimers = {};

  void _onEvent(SellFlowEvent event, Emitter<SellFlowState> emit) {
    final next = transitionSellFlow(state, event);
    if (identical(next.state, state) && next.effects.isEmpty) return;
    if (!identical(next.state, state)) emit(next.state);
    _run(next.effects);
  }

  void _run(List<SellFlowEffect> effects) {
    final session = _session;
    if (session == null) return;
    for (final effect in effects) {
      switch (effect) {
        case SellLoadContext(:final attempt):
          _answer(
            _loadContext
                .execute(session)
                .then((r) => SellContextLoaded(attempt, r)),
          );
        case SellReloadForDetour():
          _answer(_loadContext.execute(session).then(SellDetourLoaded.new));
        case SellFetchRate(:final market):
          _answer(
            _getMarketRate
                .execute(market)
                .then((r) => SellAmountChanged(AmountRateArrived(market, r))),
          );
        case SellRequirementsEffect(:final effect):
          _requirements?.run([effect]);
        case SellOrderEffect(:final effect):
          _order(session, effect);
        case SellPayinEffect(:final effect):
          _payin?.run([effect]);
        case SellSpendEffect(:final effect):
          _spend?.run([effect]);
      }
    }
  }

  Order? get _quotedOrder => switch (state) {
    SellOrdering(order: OrderQuoted(:final quoted)) => quoted.order,
    SellLoading() ||
    SellAmount() ||
    SellSource() ||
    SellPayoutPick() ||
    SellRecipient() ||
    SellRequirements() ||
    SellOrdering() ||
    SellPaying() ||
    SellDone() ||
    SellSessionEnded() ||
    SellClosed() => null,
  };

  void _order(ExchangeSession session, OrderStepEffect<SellRequest> effect) {
    switch (effect) {
      case final OrderSendCreate<SellRequest> send:
        _sentAt[send.attempt] = clock.now();
        _answer(_createOrder.execute(session, send).then(SellOrderChanged.new));
      case OrderFindCreated(:final request, :final attempt):
        _answer(
          _findCreatedOrder
              .execute<Order>(
                session,
                request.journal,
                _sentAt[attempt] ?? clock.now(),
              )
              .then((r) => SellOrderChanged(OrderFindAnswered(attempt, r))),
        );
      case OrderStartLockTimer(:final orderId):
        // The quote holds until the order's payment deadline.
        final deadline = _quotedOrder?.confirmationDeadline;
        if (deadline == null) break;
        final left = deadline.difference(clock.now());
        _arm(
          orderId,
          left.isNegative ? Duration.zero : left,
          () => OrderLockDue<SellRequest, Order>(orderId),
        );
      case OrderRefresh(:final orderId):
        final order = switch (state) {
          SellOrdering(order: OrderQuoted(:final quoted)) => quoted.order,
          SellPaying(:final quoted) => quoted.order,
          SellLoading() ||
          SellAmount() ||
          SellSource() ||
          SellPayoutPick() ||
          SellRecipient() ||
          SellRequirements() ||
          SellOrdering() ||
          SellDone() ||
          SellSessionEnded() ||
          SellClosed() => null,
        };
        if (order == null || order.orderId != orderId) break;
        _answer(
          _refreshOrder
              .execute(session, order)
              .then((r) => SellOrderChanged(OrderRefreshed(orderId, r))),
        );
      case OrderScheduleRefreshRetry(:final orderId):
        _arm(
          orderId,
          const Duration(seconds: 5),
          () => OrderRetryDue<SellRequest, Order>(orderId),
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
    OrderStepEvent<SellRequest, Order> Function() event,
  ) {
    _quoteTimers.remove(orderId)?.cancel();
    _quoteTimers[orderId] = Timer(after, () {
      _quoteTimers.remove(orderId);
      if (!isClosed) add(SellOrderChanged(event()));
    });
  }

  void _answer(Future<SellFlowEvent> answer) {
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
    for (final timer in _quoteTimers.values) {
      timer.cancel();
    }
    _quoteTimers.clear();
    await _access.cancel();
    return super.close();
  }
}
