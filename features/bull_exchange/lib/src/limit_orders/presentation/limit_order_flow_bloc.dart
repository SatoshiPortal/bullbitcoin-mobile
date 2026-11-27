import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_state.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_event.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_effect.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_limit_receive_address_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_recent_limit_orders_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/load_limit_order_context_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/validate_lightning_address_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// Shell of [LimitFlowState.next]: applies events one at a time, emits the
/// new state and runs each effect through its use case with the flow's
/// session. Every answer carries the attempt, market or option that asked
/// for it; the machine drops stale ones.
class LimitFlowBloc extends Bloc<LimitFlowEvent, LimitFlowState> {
  LimitFlowBloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
    required LoadLimitOrderContextUsecase loadContext,
    required GetLimitOrderRateUsecase getRate,
    required GetLimitReceiveAddressUsecase getReceiveAddress,
    required ValidateLightningAddressUsecase validateLightningAddress,
    required CreateLimitOrderUsecase createOrder,
    required GetRecentLimitOrdersUsecase getRecentOrders,
  }) : this._(
         limitFlowStart(session),
         session,
         accessChanges,
         loadContext,
         getRate,
         getReceiveAddress,
         validateLightningAddress,
         createOrder,
         getRecentOrders,
       );

  LimitFlowBloc._(
    LimitFlowNext start,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    this._loadContext,
    this._getRate,
    this._getReceiveAddress,
    this._validateLightningAddress,
    this._createOrder,
    this._getRecentOrders,
  ) : super(start.state) {
    on<LimitFlowEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(LimitSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  /// The session the flow opened with; null runs nothing (the flow starts
  /// ended).
  final ExchangeSession? _session;
  final LoadLimitOrderContextUsecase _loadContext;
  final GetLimitOrderRateUsecase _getRate;
  final GetLimitReceiveAddressUsecase _getReceiveAddress;
  final ValidateLightningAddressUsecase _validateLightningAddress;
  final CreateLimitOrderUsecase _createOrder;
  final GetRecentLimitOrdersUsecase _getRecentOrders;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(LimitFlowEvent event, Emitter<LimitFlowState> emit) {
    final next = state.next(event);
    if (identical(next.state, state) && next.effects.isEmpty) return;
    if (!identical(next.state, state)) emit(next.state);
    _run(next.effects);
  }

  void _run(List<LimitFlowEffect> effects) {
    final session = _session;
    if (session == null) return;
    for (final effect in effects) {
      switch (effect) {
        case LimitLoadContext(:final attempt):
          _answer(
            _loadContext
                .execute(session)
                .then((r) => LimitContextLoaded(attempt, r)),
          );
        case LimitReloadForDetour():
          _answer(_loadContext.execute(session).then(LimitDetourLoaded.new));
        case LimitFetchTargetRate(:final market, :final attempt):
          _answer(
            _getRate
                .execute(session, market)
                .then((r) => LimitTargetRateArrived(market, attempt, r)),
          );
        case LimitFetchReviewRate(:final market, :final attempt):
          _answer(
            _getRate
                .execute(session, market)
                .then((r) => LimitReviewRateArrived(attempt, r)),
          );
        case LimitDestinationEffect(:final effect):
          _destination(effect);
        case LimitConfirmEffect(:final effect):
          _confirm(session, effect);
      }
    }
  }

  void _destination(PickEffect<DestinationOption> effect) {
    switch (effect) {
      case PickResolve(:final option):
        final Future<Result<Destination, ExchangeFailure>> resolved =
            switch (option) {
              final DestinationOptionAppWallet wallet =>
                _getReceiveAddress.execute(wallet),
              // A default wallet is a value at once (destinationResolution).
              DestinationOptionDefaultWallet(:final rail, :final address) =>
                Future.value(Ok(DestinationDefaultWallet(rail, address))),
            };
        _answer(
          resolved.then(
            (r) => LimitDestinationChanged(PickResolved(option, r)),
          ),
        );
      case PickValidate(:final text):
        _answer(
          _validateLightningAddress
              .execute(text)
              .then((r) => LimitDestinationChanged(PickValidated(text, r))),
        );
    }
  }

  void _confirm(
    ExchangeSession session,
    ServerConfirmEffect<LimitOrderRequest> effect,
  ) {
    switch (effect) {
      case final ConfirmSend<LimitOrderRequest> send:
        _answer(
          _createOrder.execute(session, send).then(LimitConfirmChanged.new),
        );
      case ConfirmVerify(:final target, :final attempt):
        _answer(
          _getRecentOrders
              .execute(session)
              .then(
                (read) => LimitConfirmChanged(
                  ConfirmVerified(attempt, limitOrderCreateCheck(target, read)),
                ),
              ),
        );
    }
  }

  void _answer(Future<LimitFlowEvent> answer) {
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
