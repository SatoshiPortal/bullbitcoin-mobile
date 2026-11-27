import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/funding/domain/fund_state.dart';
import 'package:bull_exchange/src/funding/domain/fund_event.dart';
import 'package:bull_exchange/src/funding/domain/fund_effect.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_cop_funding_institutions_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_account_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_consent_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_instructions_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/save_funding_consent_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shell of [FundFlowState.next]: applies events one at a time and runs the
/// effects of the state it enters through their use cases with the flow's
/// session. Every answer carries the attempt (and request) that asked for
/// it; the machine drops stale ones.
class FundFlowBloc extends Bloc<FundFlowEvent, FundFlowState> {
  FundFlowBloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
    required GetFundingAccountUsecase getAccount,
    required SaveFundingConsentUsecase saveConsent,
    required GetFundingConsentUsecase getConsent,
    required GetCopFundingInstitutionsUsecase getInstitutions,
    required GetFundingInstructionsUsecase getInstructions,
  }) : this._(
         fundFlowStart(session),
         session,
         accessChanges,
         getAccount,
         saveConsent,
         getConsent,
         getInstitutions,
         getInstructions,
       );

  FundFlowBloc._(
    FundFlowNext start,
    this._session,
    Stream<ExchangeAccess> accessChanges,
    this._getAccount,
    this._saveConsent,
    this._getConsent,
    this._getInstitutions,
    this._getInstructions,
  ) : super(start.state) {
    on<FundFlowEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(FundSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  /// The session the flow opened with; a change ends the flow.
  final ExchangeSession? _session;
  final GetFundingAccountUsecase _getAccount;
  final SaveFundingConsentUsecase _saveConsent;
  final GetFundingConsentUsecase _getConsent;
  final GetCopFundingInstitutionsUsecase _getInstitutions;
  final GetFundingInstructionsUsecase _getInstructions;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(FundFlowEvent event, Emitter<FundFlowState> emit) {
    final next = state.next(event);
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
        await _getAccount.execute(session),
      ),
      FundSubmitConsent(:final attempt) => FundConsentSubmitted(
        attempt,
        await _saveConsent.execute(session),
      ),
      FundVerifyConsent(:final attempt) => FundConsentVerified(
        attempt,
        await _getConsent.execute(session),
      ),
      FundLoadInstitutions(:final attempt) => FundInstitutionsLoaded(
        attempt,
        await _getInstitutions.execute(session),
      ),
      FundFetchInstructions(:final attempt, :final request) =>
        FundInstructionsLoaded(
          attempt,
          request,
          await _getInstructions.execute(session, request),
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
