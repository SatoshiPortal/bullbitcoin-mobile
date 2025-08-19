import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_funding_details_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fund_exchange_event.dart';
part 'fund_exchange_state.dart';
part 'fund_exchange_bloc.freezed.dart';

class FundExchangeBloc extends Bloc<FundExchangeEvent, FundExchangeState> {
  FundExchangeBloc({
    required GetExchangeFundingDetailsUsecase getExchangeFundingDetailsUseCase,
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUseCase,
  }) : _getExchangeFundingDetailsUseCase = getExchangeFundingDetailsUseCase,
       _getExchangeUserSummaryUseCase = getExchangeUserSummaryUseCase,
       super(const FundExchangeState()) {
    on<FundExchangeJurisdictionChanged>(_onJurisdictionChanged);
    on<FundExchangeNoCoercionConfirmed>(_onNoCoercionConfirmed);
    on<FundExchangeFundingDetailsRequested>(_onFundingDetailsRequested);
  }

  final GetExchangeFundingDetailsUsecase _getExchangeFundingDetailsUseCase;
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUseCase;

  void _onJurisdictionChanged(
    FundExchangeJurisdictionChanged event,
    Emitter<FundExchangeState> emit,
  ) {
    emit(state.copyWith(jurisdiction: event.jurisdiction));
  }

  void _onNoCoercionConfirmed(
    FundExchangeNoCoercionConfirmed event,
    Emitter<FundExchangeState> emit,
  ) {
    emit(state.copyWith(hasConfirmedNoCoercion: event.confirmed));
  }

  Future<void> _onFundingDetailsRequested(
    FundExchangeFundingDetailsRequested event,
    Emitter<FundExchangeState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          fundingDetails: null,
          getExchangeFundingDetailsException: null,
        ),
      );

      final fundingDetails = await _getExchangeFundingDetailsUseCase.execute(
        fundingMethod: event.fundingMethod,
        jurisdiction: state.jurisdiction,
      );
      emit(state.copyWith(fundingDetails: fundingDetails));

      if (state.userSummary == null) {
        final userSummary = await _getExchangeUserSummaryUseCase.execute();
        emit(state.copyWith(userSummary: userSummary));
      }
    } catch (e) {
      debugPrint('Error handling email e-transfer request: $e');
      if (e is GetExchangeFundingDetailsException) {
        emit(state.copyWith(getExchangeFundingDetailsException: e));
      }
    }
  }
}
