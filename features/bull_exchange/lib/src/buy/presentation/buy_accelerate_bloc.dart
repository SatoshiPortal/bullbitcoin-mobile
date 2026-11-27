import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/buy/domain/buy_accelerate_flow.dart';
import 'package:bull_exchange/src/buy/domain/usecases/accelerate_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/load_accelerate_quote_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell of [AccelerateFlowState.next]: applies events one at a time, emits
/// the new state and runs each effect through its use case with the flow's
/// session, each answer tagged with its attempt.
class AccelerateFlowBloc
    extends Bloc<AccelerateFlowEvent, AccelerateFlowState> {
  AccelerateFlowBloc({
    required ExchangeSession? session,
    required String orderId,
    required Stream<ExchangeAccess> accessChanges,
    required LoadAccelerateQuoteUsecase loadQuote,
    required AccelerateBuyOrderUsecase accelerateOrder,
    required GetOrderUsecase getOrder,
  }) : this._(
         accelerateFlowStart(session, orderId),
         session,
         accessChanges,
         loadQuote,
         accelerateOrder,
         getOrder,
       );

  AccelerateFlowBloc._(
    AccelerateFlowNext start,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    this._loadQuote,
    this._accelerateOrder,
    this._getOrder,
  ) : super(start.state) {
    on<AccelerateFlowEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(AccelerateSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  /// The session the flow opened with; null runs nothing (the flow starts
  /// ended).
  final ExchangeSession? _session;
  final LoadAccelerateQuoteUsecase _loadQuote;
  final AccelerateBuyOrderUsecase _accelerateOrder;
  final GetOrderUsecase _getOrder;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(AccelerateFlowEvent event, Emitter<AccelerateFlowState> emit) {
    final next = state.next(event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<AccelerateFlowEffect> effects) {
    final session = _session;
    if (session == null) return;
    for (final effect in effects) {
      switch (effect) {
        case AccelerateLoad(:final orderId, :final attempt):
          _answer(
            _loadQuote
                .execute(session, orderId)
                .then((r) => AccelerateLoaded(attempt, r)),
          );
        case AccelerateConfirmEffect(
          effect: final ConfirmSend<AccelerateTarget> send,
        ):
          _answer(
            _accelerateOrder
                .execute(session, send)
                .then(AccelerateConfirmChanged.new),
          );
        case AccelerateConfirmEffect(
          effect: ConfirmVerify(:final target, :final attempt),
        ):
          _answer(
            _getOrder
                .execute(session, target.orderId)
                .then(
                  (read) => AccelerateConfirmChanged(
                    ConfirmVerified(attempt, accelerateConfirmCheck(read)),
                  ),
                ),
          );
      }
    }
  }

  void _answer(Future<AccelerateFlowEvent> answer) {
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
