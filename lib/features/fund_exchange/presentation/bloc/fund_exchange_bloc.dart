import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_error.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fund_exchange_event.dart';
part 'fund_exchange_state.dart';
part 'fund_exchange_bloc.freezed.dart';

class FundExchangeBloc extends Bloc<FundExchangeEvent, FundExchangeState> {
  FundExchangeBloc({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required GetFundingDetailsUsecase getFundingDetailsUsecase,
    required ListFundingInstitutionsUsecase listFundingInstitutionsUsecase,
    required RegisterResponsibilityConsentUsecase
    registerResponsibilityConsentUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _getFundingDetailsUsecase = getFundingDetailsUsecase,
       _listFundingInstitutionsUsecase = listFundingInstitutionsUsecase,
       _registerResponsibilityConsentUsecase =
           registerResponsibilityConsentUsecase,
       super(const FundExchangeState()) {
    on<FundExchangeStarted>(_onStarted);
    on<FundExchangeFundingInstitutionsRequested>(
      _onFundingInstitutionsRequested,
    );
    on<FundExchangeFundingDetailsRequested>(_onFundingDetailsRequested);
    on<FundExchangeScamWarningConsentSubmitted>(_onScamWarningConsentSubmitted);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetFundingDetailsUsecase _getFundingDetailsUsecase;
  final ListFundingInstitutionsUsecase _listFundingInstitutionsUsecase;
  final RegisterResponsibilityConsentUsecase
  _registerResponsibilityConsentUsecase;

  Future<void> _onStarted(
    FundExchangeStarted event,
    Emitter<FundExchangeState> emit,
  ) async {
    try {
      final summary = await _getExchangeUserSummaryUsecase.execute();

      // To test scam warning consent flow.
      // Comment out before production.
      //final groups = summary.groups.toList();
      //groups.remove('CONSENT_SCAM_WARNING');
      //emit(state.copyWith(userSummary: summary.copyWith(groups: groups)));

      emit(state.copyWith(userSummary: summary));
    } on ApiKeyException catch (e) {
      emit(state.copyWith(apiKeyException: e));
    } on GetExchangeUserSummaryException catch (e) {
      emit(state.copyWith(getUserSummaryException: e));
    } finally {
      emit(state.copyWith(isStarted: true));
    }
  }

  Future<void> _onFundingInstitutionsRequested(
    FundExchangeFundingInstitutionsRequested event,
    Emitter<FundExchangeState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          fundingInstitutions: null,
          listFundingInstitutionsException: null,
          isLoadingFundingInstitutions: true,
        ),
      );

      final result = await _listFundingInstitutionsUsecase.execute(
        ListFundingInstitutionsQuery(jurisdictionCode: event.jurisdiction.code),
      );

      emit(state.copyWith(fundingInstitutions: result.institutions));
    } on FundExchangeApplicationError catch (e) {
      emit(
        state.copyWith(
          listFundingInstitutionsException:
              FundExchangePresentationError.fromApplicationError(e),
        ),
      );
    } catch (e) {
      emit(state.copyWith(listFundingInstitutionsException: UnexpectedError()));
    } finally {
      emit(state.copyWith(isLoadingFundingInstitutions: false));
    }
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
          isLoadingFundingDetails: true,
        ),
      );

      GetFundingDetailsQuery query;
      switch (event.fundingMethod) {
        case EmailETransfer():
          query = GetEmailETransferDetails();
          break;
        case BankTransferWire():
          query = GetBankTransferWireDetails();
          break;
        case OnlineBillPayment():
          query = GetOnlineBillPaymentDetails();
          break;
        case CanadaPost():
          query = GetCanadaPostDetails();
          break;
        case InstantSepa():
          query = GetInstantSepaDetails();
          break;
        case RegularSepa():
          query = GetRegularSepaDetails();
          break;
        case SpeiTransfer():
          query = GetSpeiTransferDetails();
          break;
        case CrIbanCrc():
          query = GetCrIbanCrcDetails();
          break;
        case CrIbanUsd():
          query = GetCrIbanUsdDetails();
          break;
        case Sinpe():
          query = GetSinpeDetails();
          break;
        case ArsBankTransfer():
          query = GetArsBankTransferDetails();
          break;
        case CopBankTransfer(:final bankCode, :final amountCop):
          query = GetCopBankTransferDetails(
            bankCode: bankCode,
            amountCop: amountCop,
          );
          break;
      }

      final fundingDetails = await _getFundingDetailsUsecase.execute(query);

      emit(state.copyWith(fundingDetails: fundingDetails.fundingDetails));
    } on FundExchangeApplicationError catch (e) {
      emit(
        state.copyWith(
          getExchangeFundingDetailsException:
              FundExchangePresentationError.fromApplicationError(e),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(getExchangeFundingDetailsException: UnexpectedError()),
      );
    } finally {
      emit(state.copyWith(isLoadingFundingDetails: false));
    }
  }

  Future<void> _onScamWarningConsentSubmitted(
    FundExchangeScamWarningConsentSubmitted event,
    Emitter<FundExchangeState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          submitScamWarningConsentException: null,
          isSubmittingScamWarningConsent: true,
        ),
      );

      await _registerResponsibilityConsentUsecase.execute(
        const RegisterResponsibilityConsentCommand(),
      );

      // Fetch and update user summary to reflect consent
      final updatedSummary = await _getExchangeUserSummaryUsecase.execute();
      emit(state.copyWith(userSummary: updatedSummary));
    } on FundExchangeApplicationError catch (e) {
      emit(
        state.copyWith(
          submitScamWarningConsentException:
              FundExchangePresentationError.fromApplicationError(e),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(submitScamWarningConsentException: UnexpectedError()),
      );
    } finally {
      emit(state.copyWith(isSubmittingScamWarningConsent: false));
    }
  }
}
