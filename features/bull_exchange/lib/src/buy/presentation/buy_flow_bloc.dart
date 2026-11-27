import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/domain/usecases/confirm_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/create_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/find_created_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/get_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/get_buy_receive_address_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/load_buy_context_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/refresh_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/release_buy_payjoin_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/settle_buy_payout_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/validate_buy_address_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:bull_exchange/src/payin/outcome_watch_runner.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell of [transitionBuyFlow]: applies events one at a time, emits the
/// new state and runs each effect through its use case with the flow's
/// session. Every answer carries the attempt, order
/// id, option, text or ticket that asked for it; the machine drops stale
/// ones.
class BuyFlowBloc extends Bloc<BuyFlowEvent, BuyFlowState> {
  BuyFlowBloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
    required LoadBuyContextUsecase loadContext,
    required GetMarketRateUsecase getMarketRate,
    required GetBuyReceiveAddressUsecase getReceiveAddress,
    required ValidateBuyAddressUsecase validateAddress,
    required CreateBuyOrderUsecase createOrder,
    required FindCreatedBuyOrderUsecase findCreatedOrder,
    required RefreshBuyOrderUsecase refreshOrder,
    required ConfirmBuyOrderUsecase confirmOrder,
    required GetOrderUsecase getOrder,
    required GetBuyOrderUsecase getBuyOrder,
    required ReleaseBuyPayjoinUsecase releasePayjoin,
    required SettleBuyPayoutUsecase settlePayout,
    Duration refreshRetryAfter = const Duration(seconds: 5),
  }) : this._(
         buyFlowStart(session),
         session,
         accessChanges,
         loadContext,
         getMarketRate,
         getReceiveAddress,
         validateAddress,
         createOrder,
         findCreatedOrder,
         refreshOrder,
         confirmOrder,
         getOrder,
         getBuyOrder,
         releasePayjoin,
         settlePayout,
         refreshRetryAfter,
       );

  BuyFlowBloc._(
    BuyFlowNext start,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    this._loadContext,
    this._getMarketRate,
    this._getReceiveAddress,
    this._validateAddress,
    this._createOrder,
    this._findCreatedOrder,
    this._refreshOrder,
    this._confirmOrder,
    this._getOrder,
    GetBuyOrderUsecase getBuyOrder,
    this._releasePayjoin,
    this._settlePayout,
    this._refreshRetryAfter,
  ) : super(start.state) {
    on<BuyFlowEvent>(_onEvent, transformer: sequential());
    final session = _session;
    if (session != null) {
      _watch = OutcomeWatchRunner(
        (orderId) => getBuyOrder.execute(session, orderId),
        (event) {
          if (!isClosed) add(BuyWatchChanged(event));
        },
      );
    }
    _access = accessChanges.listen((access) {
      if (!isClosed) add(BuySessionChanged(access.signedInSession));
    });
    _run(start.effects, start.state);
  }

  /// The session the flow opened with; null runs nothing (the flow starts
  /// ended).
  final ExchangeSession? _session;
  final LoadBuyContextUsecase _loadContext;
  final GetMarketRateUsecase _getMarketRate;
  final GetBuyReceiveAddressUsecase _getReceiveAddress;
  final ValidateBuyAddressUsecase _validateAddress;
  final CreateBuyOrderUsecase _createOrder;
  final FindCreatedBuyOrderUsecase _findCreatedOrder;
  final RefreshBuyOrderUsecase _refreshOrder;
  final ConfirmBuyOrderUsecase _confirmOrder;
  final GetOrderUsecase _getOrder;
  final ReleaseBuyPayjoinUsecase _releasePayjoin;
  final SettleBuyPayoutUsecase _settlePayout;
  final Duration _refreshRetryAfter;
  OutcomeWatchRunner<BuyOrder>? _watch;
  late final StreamSubscription<ExchangeAccess> _access;
  final Map<String, Timer> _locks = {};
  final Map<String, Timer> _retries = {};

  /// When each create attempt was sent: the re-read after an unknown outcome
  /// matches orders created around it.
  final Map<int, DateTime> _sentAt = {};

  void _onEvent(BuyFlowEvent event, Emitter<BuyFlowState> emit) {
    final before = state;
    final next = transitionBuyFlow(before, event);
    if (identical(next.state, before) && next.effects.isEmpty) return;
    if (!identical(next.state, before)) emit(next.state);
    _run(next.effects, before);
  }

  /// Runs [effects]; [before] is the state that left, for the order an
  /// effect names.
  void _run(List<BuyFlowEffect> effects, BuyFlowState before) {
    final session = _session;
    if (session == null) return;
    for (final effect in effects) {
      switch (effect) {
        case BuyLoadContext(:final attempt):
          _answer(
            _loadContext
                .execute(session)
                .then((r) => BuyContextLoaded(attempt, r)),
          );
        case BuyReloadForDetour():
          _answer(_loadContext.execute(session).then(BuyDetourLoaded.new));
        case BuyFetchRate(:final market):
          _answer(
            _getMarketRate
                .execute(session, market)
                .then((r) => BuyAmountChanged(AmountRateArrived(market, r))),
          );
        case BuyDestinationEffect(:final effect):
          _destination(effect);
        case BuyOrderEffect(:final effect):
          _order(session, effect, before);
        case BuyConfirmEffect(:final effect):
          _confirm(session, effect);
        case BuyWatchEffect(:final effect):
          _watch?.run(effect);
        case BuyPayoutSettled(:final order, :final walletId):
          unawaited(_settlePayout.execute(order, walletId));
      }
    }
  }

  void _destination(PickEffect<DestinationOption> effect) {
    switch (effect) {
      case PickResolve(option: final DestinationOptionAppWallet option):
        _answer(
          _getReceiveAddress
              .execute(option)
              .then((r) => BuyDestinationChanged(PickResolved(option, r))),
        );
      // Buy offers no exchange default wallet (bd t-54y).
      case PickResolve(option: DestinationOptionDefaultWallet()):
        break;
      case PickValidate(:final text):
        _answer(
          _validateAddress
              .execute(text)
              .then((r) => BuyDestinationChanged(PickValidated(text, r))),
        );
    }
  }

  void _order(
    ExchangeSession session,
    OrderStepEffect<BuyRequest> effect,
    BuyFlowState before,
  ) {
    switch (effect) {
      case final OrderSendCreate<BuyRequest> send:
        _sentAt[send.attempt] = clock.now();
        _answer(_createOrder.execute(session, send).then(BuyOrderChanged.new));
      case OrderFindCreated(:final request, :final attempt):
        _answer(
          _findCreatedOrder
              .execute(session, request, _sentAt[attempt] ?? clock.now())
              .then((r) => BuyOrderChanged(OrderFindAnswered(attempt, r))),
        );
      case OrderStartLockTimer(:final orderId):
        _locks.remove(orderId)?.cancel();
        final current = state;
        final deadline =
            current is BuyReview && current.order.orderId == orderId
            ? current.order.confirmationDeadline
            : null;
        if (deadline == null) break;
        final wait = deadline.difference(clock.now());
        _locks[orderId] = Timer(wait.isNegative ? Duration.zero : wait, () {
          if (!isClosed) add(BuyOrderChanged(OrderLockDue(orderId)));
        });
      case OrderRefresh(:final orderId):
        _answer(
          _refreshOrder
              .execute(session, orderId)
              .then((r) => BuyOrderChanged(OrderRefreshed(orderId, r))),
        );
      case OrderScheduleRefreshRetry(:final orderId):
        _retries.remove(orderId)?.cancel();
        _retries[orderId] = Timer(_refreshRetryAfter, () {
          if (!isClosed) add(BuyOrderChanged(OrderRetryDue(orderId)));
        });
      case OrderStopTimers(:final orderId):
        _locks.remove(orderId)?.cancel();
        _retries.remove(orderId)?.cancel();
      case OrderRelease(:final orderId):
        if (before case BuyReview(:final order) when order.orderId == orderId) {
          unawaited(_releasePayjoin.execute(order));
        }
    }
  }

  void _confirm(
    ExchangeSession session,
    ServerConfirmEffect<BuyConfirmTarget> effect,
  ) {
    switch (effect) {
      case final ConfirmSend<BuyConfirmTarget> send:
        _answer(
          _confirmOrder.execute(session, send).then(BuyConfirmChanged.new),
        );
      case ConfirmVerify(:final target, :final attempt):
        _answer(
          _getOrder
              .execute(session, target.order.orderId)
              .then(
                (read) => BuyConfirmChanged(
                  ConfirmVerified(attempt, buyConfirmCheck(read)),
                ),
              ),
        );
    }
  }

  void _answer(Future<BuyFlowEvent> answer) {
    unawaited(
      answer.then((event) {
        if (!isClosed) add(event);
      }),
    );
  }

  @override
  Future<void> close() async {
    // Leaving with a quote on screen abandons it; a confirm in flight or a
    // confirmed order keeps its payjoin (BUY-5).
    if (_session != null) {
      if (state case BuyReview(:final order)) {
        unawaited(_releasePayjoin.execute(order));
      }
    }
    for (final timer in [..._locks.values, ..._retries.values]) {
      timer.cancel();
    }
    _watch?.close();
    await _access.cancel();
    return super.close();
  }
}
