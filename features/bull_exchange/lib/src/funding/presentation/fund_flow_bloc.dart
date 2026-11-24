import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/funding/presentation/fund_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell of [transitionFundFlow]: applies events one at a time and runs the
/// effects of the state it enters. Every answer carries the attempt (and
/// request) that asked for it; the machine drops stale ones.
class FundFlowBloc extends Bloc<FundFlowEvent, FundFlowState> {
  FundFlowBloc({
    required ExchangeFunding funding,
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) : this._(funding, session, accessChanges, fundFlowStart(session));

  FundFlowBloc._(
    this._funding,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    FundFlowNext start,
  ) : super(start.state) {
    on<FundFlowEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(FundSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  final ExchangeFunding _funding;

  /// The session the flow opened with; a change ends the flow.
  final ExchangeSession? _session;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(FundFlowEvent event, Emitter<FundFlowState> emit) {
    final next = transitionFundFlow(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<FundFlowEffect> effects) {
    final session = _session;
    if (session == null) return;
    for (final effect in effects) {
      unawaited(_effect(session, effect));
    }
  }

  Future<void> _effect(ExchangeSession session, FundFlowEffect effect) async {
    final FundFlowEvent answer = switch (effect) {
      FundLoadAccount(:final attempt) => FundAccountLoaded(
        attempt,
        await _funding.account(session),
      ),
      FundSubmitConsent(:final attempt) => FundConsentSubmitted(
        attempt,
        await _funding.consent(session),
      ),
      FundVerifyConsent(:final attempt) => FundConsentVerified(
        attempt,
        await _funding.consentOnAccount(session),
      ),
      FundLoadInstitutions(:final attempt) => FundInstitutionsLoaded(
        attempt,
        await _funding.institutions(
          session,
          const CopBankTransferRail().jurisdiction,
        ),
      ),
      FundFetchInstructions(:final attempt, :final request) =>
        FundInstructionsLoaded(
          attempt,
          request,
          await _funding.instructions(session, request),
        ),
    };
    if (!isClosed) add(answer);
  }

  @override
  Future<void> close() async {
    await _access.cancel();
    return super.close();
  }
}
