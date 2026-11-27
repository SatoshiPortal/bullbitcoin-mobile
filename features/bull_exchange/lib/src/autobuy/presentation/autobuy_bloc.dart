import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/account/domain/usecases/get_user_summary_usecase.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_state.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_event.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_effect.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch_state.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch_event.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch_effect.dart';
import 'package:bull_exchange/src/autobuy/domain/usecases/load_autobuy_context_usecase.dart';
import 'package:bull_exchange/src/autobuy/domain/usecases/save_autobuy_preference_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell of [AutoBuyFlowState.next]: runs each effect through its use case
/// with the flow's session.
class AutoBuyFlowBloc extends Bloc<AutoBuyFlowEvent, AutoBuyFlowState> {
  AutoBuyFlowBloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
    required LoadAutoBuyContextUsecase loadContext,
    required SaveAutoBuyPreferenceUsecase saveAutoBuy,
    required GetUserSummaryUsecase getUserSummary,
  }) : this._(
         autoBuyFlowStart(session),
         session,
         accessChanges,
         loadContext,
         saveAutoBuy,
         getUserSummary,
       );

  AutoBuyFlowBloc._(
    AutoBuyFlowNext start,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    this._loadContext,
    this._saveAutoBuy,
    this._getUserSummary,
  ) : super(start.state) {
    on<AutoBuyFlowEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(AutoBuySessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  /// The session the flow opened with; null runs nothing (the flow starts
  /// ended).
  final ExchangeSession? _session;
  final LoadAutoBuyContextUsecase _loadContext;
  final SaveAutoBuyPreferenceUsecase _saveAutoBuy;
  final GetUserSummaryUsecase _getUserSummary;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(AutoBuyFlowEvent event, Emitter<AutoBuyFlowState> emit) {
    final next = state.next(event);
    if (identical(next.state, state) && next.effects.isEmpty) return;
    if (!identical(next.state, state)) emit(next.state);
    _run(next.effects);
  }

  void _run(List<AutoBuyFlowEffect> effects) {
    final session = _session;
    if (session == null) return;
    for (final effect in effects) {
      final Future<AutoBuyFlowEvent> answer = switch (effect) {
        AutoBuyLoadContext(:final attempt) =>
          _loadContext
              .execute(session)
              .then((r) => AutoBuyContextLoaded(attempt, r)),
        AutoBuyReloadForKyc() =>
          _loadContext.execute(session).then(AutoBuyKycReloaded.new),
        AutoBuyConfirmEffect(effect: final ConfirmSend<AutoBuyTarget> send) =>
          _saveAutoBuy.execute(session, send).then(AutoBuyConfirmChanged.new),
        AutoBuyConfirmEffect(
          effect: ConfirmVerify(:final target, :final attempt),
        ) =>
          _getUserSummary
              .execute(session)
              .then(
                (read) => AutoBuyConfirmChanged(
                  ConfirmVerified(attempt, autoBuyCheck(target, read)),
                ),
              ),
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
    await _access.cancel();
    return super.close();
  }
}

/// Shell of [AutoBuySwitchState.next]. Without a session the switch only
/// shows the summary.
class AutoBuySwitchBloc extends Bloc<AutoBuySwitchEvent, AutoBuySwitchState> {
  AutoBuySwitchBloc({
    required this._session,
    required this._saveAutoBuy,
    required this._getUserSummary,
    required bool active,
    required bool restricted,
    required this._onAccountChanged,
  }) : super(autoBuySwitchStart(active: active, restricted: restricted).state) {
    on<AutoBuySwitchEvent>(_onEvent, transformer: sequential());
  }

  /// The session the card was built with; null writes nothing.
  final ExchangeSession? _session;
  final SaveAutoBuyPreferenceUsecase _saveAutoBuy;
  final GetUserSummaryUsecase _getUserSummary;
  final Future<void> Function() _onAccountChanged;

  void _onEvent(AutoBuySwitchEvent event, Emitter<AutoBuySwitchState> emit) {
    if (_session == null && event is SwitchDeactivatePressed) return;
    final next = state.next(event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<AutoBuySwitchEffect> effects) {
    final session = _session;
    for (final effect in effects) {
      switch (effect) {
        case SwitchAccountChanged():
          unawaited(_onAccountChanged());
        case SwitchConfirmEffect(:final effect):
          if (session == null) continue;
          final Future<AutoBuySwitchEvent> answer = switch (effect) {
            final ConfirmSend<AutoBuyTarget> send =>
              _saveAutoBuy
                  .execute(session, send)
                  .then(SwitchConfirmChanged.new),
            ConfirmVerify(:final target, :final attempt) =>
              _getUserSummary
                  .execute(session)
                  .then(
                    (read) => SwitchConfirmChanged(
                      ConfirmVerified(attempt, autoBuyCheck(target, read)),
                    ),
                  ),
          };
          unawaited(
            answer.then((event) {
              if (!isClosed) add(event);
            }),
          );
      }
    }
  }
}
