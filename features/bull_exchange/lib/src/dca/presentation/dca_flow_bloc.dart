import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/account/domain/usecases/get_user_summary_usecase.dart';
import 'package:bull_exchange/src/dca/domain/dca_flow.dart';
import 'package:bull_exchange/src/dca/domain/usecases/activate_dca_usecase.dart';
import 'package:bull_exchange/src/dca/domain/usecases/create_dca_usecase.dart';
import 'package:bull_exchange/src/dca/domain/usecases/load_dca_context_usecase.dart';
import 'package:bull_exchange/src/default_wallets/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell of [transitionDcaFlow]: applies events one at a time, emits the
/// new state and runs each effect through its use case with the flow's
/// session, each answer tagged with its attempt or ticket.
class DcaFlowBloc extends Bloc<DcaFlowEvent, DcaFlowState> {
  DcaFlowBloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
    required LoadDcaContextUsecase loadContext,
    required GetMarketRateUsecase getMarketRate,
    required GetDefaultWalletsUsecase getDefaultWallets,
    required CreateDcaUsecase createDca,
    required GetUserSummaryUsecase getUserSummary,
    required ActivateDcaUsecase activateDca,
  }) : this._(
         dcaFlowStart(session),
         session,
         accessChanges,
         loadContext,
         getMarketRate,
         getDefaultWallets,
         createDca,
         getUserSummary,
         activateDca,
       );

  DcaFlowBloc._(
    DcaFlowNext start,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    this._loadContext,
    this._getMarketRate,
    this._getDefaultWallets,
    this._createDca,
    this._getUserSummary,
    this._activateDca,
  ) : super(start.state) {
    on<DcaFlowEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(DcaSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  /// The session the flow opened with; null runs nothing (the flow starts
  /// ended).
  final ExchangeSession? _session;
  final LoadDcaContextUsecase _loadContext;
  final GetMarketRateUsecase _getMarketRate;
  final GetDefaultWalletsUsecase _getDefaultWallets;
  final CreateDcaUsecase _createDca;
  final GetUserSummaryUsecase _getUserSummary;
  final ActivateDcaUsecase _activateDca;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(DcaFlowEvent event, Emitter<DcaFlowState> emit) {
    final before = state;
    final next = transitionDcaFlow(before, event);
    if (identical(next.state, before) && next.effects.isEmpty) return;
    if (!identical(next.state, before)) emit(next.state);
    _run(next.effects);
  }

  void _run(List<DcaFlowEffect> effects) {
    final session = _session;
    if (session == null) return;
    for (final effect in effects) {
      switch (effect) {
        case DcaLoadContext(:final attempt):
          _answer(
            _loadContext
                .execute(session)
                .then((r) => DcaContextLoaded(attempt, r)),
          );
        case DcaReloadForDetour():
          _answer(_loadContext.execute(session).then(DcaDetourLoaded.new));
        case DcaFetchRate(:final market):
          _answer(
            _getMarketRate
                .execute(market)
                .then((r) => DcaAmountChanged(AmountRateArrived(market, r))),
          );
        case DcaLoadDefaultWallets(:final ticket):
          _answer(
            _getDefaultWallets.execute().then(
              (r) => DcaDefaultWalletsLoaded(ticket, r),
            ),
          );
        case DcaConfirmEffect(effect: final ConfirmSend<DcaPlan> send):
          _answer(
            _createDca.execute(session, send).then(DcaConfirmChanged.new),
          );
        case DcaConfirmEffect(
          effect: ConfirmVerify(:final target, :final attempt),
        ):
          _answer(
            _getUserSummary
                .execute(session)
                .then(
                  (read) => DcaConfirmChanged(
                    ConfirmVerified(attempt, dcaConfirmCheck(target, read)),
                  ),
                ),
          );
        case DcaActivated():
          unawaited(_activateDca.execute(session));
      }
    }
  }

  void _answer(Future<DcaFlowEvent> answer) {
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
