import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_country.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fund_exchange_event.dart';
part 'fund_exchange_state.dart';
part 'fund_exchange_bloc.freezed.dart';

class FundExchangeBloc extends Bloc<FundExchangeEvent, FundExchangeState> {
  FundExchangeBloc({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUseCase,
  }) : _getExchangeUserSummaryUseCase = getExchangeUserSummaryUseCase,
       super(const FundExchangeState()) {
    on<FundExchangeStarted>(_onStarted);
    on<FundExchangeCountryChanged>(_onCountryChanged);
    on<FundExchangeNoCoercionConfirmed>(_onNoCoercionConfirmed);
    on<FundExchangeEmailETransferRequested>(_onEmailETransferRequested);
    on<FundExchangeBankTransferWireRequested>(_onBankTransferWireRequested);
    on<FundExchangeCanadaPostRequested>(_onCanadaPostRequested);
    on<FundExchangeOnlineBillPaymentRequested>(_onOnlineBillPaymentRequested);
    on<FundExchangeSepaTransferRequested>(_onSepaTransferRequested);
    on<FundExchangeSpeiTransferRequested>(_onSpeiTransferRequested);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUseCase;

  Future<void> _onStarted(
    FundExchangeStarted event,
    Emitter<FundExchangeState> emit,
  ) async {
    try {
      emit(state.copyWith(getUserSummaryException: null));
      final userSummary = await _getExchangeUserSummaryUseCase.execute();
      emit(state.copyWith(userSummary: userSummary));
    } on GetExchangeUserSummaryException catch (e) {
      emit(state.copyWith(getUserSummaryException: e));
    } catch (e) {
      debugPrint('Error fetching user summary: $e');
    }
  }

  void _onCountryChanged(
    FundExchangeCountryChanged event,
    Emitter<FundExchangeState> emit,
  ) {
    emit(state.copyWith(fundingCountry: event.country));
  }

  void _onNoCoercionConfirmed(
    FundExchangeNoCoercionConfirmed event,
    Emitter<FundExchangeState> emit,
  ) {
    emit(state.copyWith(hasConfirmedNoCoercion: event.confirmed));
  }

  void _onEmailETransferRequested(
    FundExchangeEmailETransferRequested event,
    Emitter<FundExchangeState> emit,
  ) {
    try {
      emit(
        state.copyWith(
          emailETransferSecretQuestion: 'secretQuestion',
          emailETransferSecretAnswer: 'secretAnswer',
        ),
      );
    } catch (e) {
      debugPrint('Error handling email e-transfer request: $e');
    }
  }

  void _onBankTransferWireRequested(
    FundExchangeBankTransferWireRequested event,
    Emitter<FundExchangeState> emit,
  ) {
    try {
      emit(state.copyWith(bankTransferWireCode: 'bankTransferWireCode'));
    } catch (e) {
      debugPrint('Error handling bank transfer wire request: $e');
    }
  }

  void _onCanadaPostRequested(
    FundExchangeCanadaPostRequested event,
    Emitter<FundExchangeState> emit,
  ) {
    try {
      emit(state.copyWith(canadaPostLoadhubQRCode: 'loadhubQRCode'));
    } catch (e) {
      debugPrint('Error handling Canada Post request: $e');
    }
  }

  void _onOnlineBillPaymentRequested(
    FundExchangeOnlineBillPaymentRequested event,
    Emitter<FundExchangeState> emit,
  ) {
    try {
      emit(state.copyWith(onlineBillPaymentAccountNumber: 'accountNumber'));
    } catch (e) {
      debugPrint('Error handling online bill payment request: $e');
    }
  }

  void _onSepaTransferRequested(
    FundExchangeSepaTransferRequested event,
    Emitter<FundExchangeState> emit,
  ) {
    try {
      emit(state.copyWith(sepaTransferCode: 'sepaTransferCode'));
    } catch (e) {
      debugPrint('Error handling SEPA transfer request: $e');
    }
  }

  void _onSpeiTransferRequested(
    FundExchangeSpeiTransferRequested event,
    Emitter<FundExchangeState> emit,
  ) {
    try {
      emit(state.copyWith(speiTransferMemo: 'speiTransferMemo'));
    } catch (e) {
      debugPrint('Error handling SPEI transfer request: $e');
    }
  }
}
