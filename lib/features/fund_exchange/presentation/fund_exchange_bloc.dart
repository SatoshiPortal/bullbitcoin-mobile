import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_confidential_sepa_funding_availability_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_fund_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/open_funding_payment_link_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/pending_consent_action.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:primitives/primitives.dart';

part 'fund_exchange_event.dart';
part 'fund_exchange_state.dart';
part 'fund_exchange_bloc.freezed.dart';

class FundExchangeBloc extends Bloc<FundExchangeEvent, FundExchangeState> {
  final GetFundExchangeUserSummaryUsecase _getFundExchangeUserSummaryUsecase;
  final GetFundingDetailsUsecase _getFundingDetailsUsecase;
  final ListFundingInstitutionsUsecase _listFundingInstitutionsUsecase;
  final RegisterResponsibilityConsentUsecase
  _registerResponsibilityConsentUsecase;
  final OpenFundingPaymentLinkUsecase _openFundingPaymentLinkUsecase;
  final GetConfidentialSepaFundingAvailabilityUsecase
  _getConfidentialSepaFundingAvailabilityUsecase;

  FundExchangeBloc({
    required this._getFundExchangeUserSummaryUsecase,
    required this._getFundingDetailsUsecase,
    required this._listFundingInstitutionsUsecase,
    required this._registerResponsibilityConsentUsecase,
    required this._openFundingPaymentLinkUsecase,
    required this._getConfidentialSepaFundingAvailabilityUsecase,
  }) : super(const FundExchangeState()) {
    on<FundExchangeStarted>(_onStarted);
    on<FundExchangeConfidentialSepaAvailabilityRetried>(
      _onConfidentialSepaAvailabilityRetried,
      transformer: droppable(),
    );
    on<FundExchangeFundingInstitutionsRequested>(
      _onFundingInstitutionsRequested,
    );
    on<FundExchangeFundingDetailsRequested>(_onFundingDetailsRequested);
    on<FundExchangeScamWarningConsentSubmitted>(_onScamWarningConsentSubmitted);
    on<FundExchangeScamWarningDismissed>(_onScamWarningDismissed);
    on<FundExchangePaymentLinkOpenRequested>(_onPaymentLinkOpenRequested);
    on<FundExchangeFundingDetailsErrorCleared>(_onFundingDetailsErrorCleared);
  }

  Future<void> _onStarted(
    FundExchangeStarted event,
    Emitter<FundExchangeState> emit,
  ) async {
    final result = await _getFundExchangeUserSummaryUsecase.execute();
    if (emit.isDone) return;

    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(userSummary: value));
      case Err():
        // Not surfaced: the screen degrades to the unrestricted, consent-less
        // default rather than blocking on a summary it can do without. The
        // use-case has already logged it.
        break;
    }

    await _loadConfidentialSepaAvailability(emit);
    if (emit.isDone) return;
    emit(state.copyWith(isStarted: true));
  }

  Future<void> _onConfidentialSepaAvailabilityRetried(
    FundExchangeConfidentialSepaAvailabilityRetried event,
    Emitter<FundExchangeState> emit,
  ) => _loadConfidentialSepaAvailability(emit);

  Future<void> _loadConfidentialSepaAvailability(
    Emitter<FundExchangeState> emit,
  ) async {
    if (state.isLoadingConfidentialSepaAvailability) return;
    emit(
      state.copyWith(
        isLoadingConfidentialSepaAvailability: true,
        confidentialSepaAvailabilityFailure: null,
      ),
    );
    final result = await _getConfidentialSepaFundingAvailabilityUsecase
        .execute();
    if (emit.isDone) return;
    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        isConfidentialSepaAvailable: value,
        isLoadingConfidentialSepaAvailability: false,
      ),
      Err(:final failure) => state.copyWith(
        confidentialSepaAvailabilityFailure: failure,
        isLoadingConfidentialSepaAvailability: false,
      ),
    });
  }

  Future<void> _onFundingInstitutionsRequested(
    FundExchangeFundingInstitutionsRequested event,
    Emitter<FundExchangeState> emit,
  ) async {
    if (state.shouldShowScamWarningConsent) {
      emit(state.copyWith(pendingConsentAction: const PendingCopInputAction()));
      return;
    }

    emit(
      state.copyWith(
        fundingInstitutions: null,
        listFundingInstitutionsFailure: null,
        isLoadingFundingInstitutions: true,
        pendingConsentAction: null,
      ),
    );

    final result = await _listFundingInstitutionsUsecase.execute(
      ListFundingInstitutionsQuery(jurisdiction: event.jurisdiction),
    );

    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        fundingInstitutions: value.institutions,
        isLoadingFundingInstitutions: false,
      ),
      Err(:final failure) => state.copyWith(
        listFundingInstitutionsFailure: failure,
        isLoadingFundingInstitutions: false,
      ),
    });
  }

  Future<void> _onFundingDetailsRequested(
    FundExchangeFundingDetailsRequested event,
    Emitter<FundExchangeState> emit,
  ) async {
    if (state.shouldShowScamWarningConsent) {
      emit(
        state.copyWith(
          pendingConsentAction: PendingFundingDetailsAction(
            event.fundingMethod,
          ),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        fundingDetails: null,
        getFundingDetailsFailure: null,
        isLoadingFundingDetails: true,
        pendingConsentAction: null,
      ),
    );

    final query = switch (event.fundingMethod) {
      EmailETransfer() => const GetEmailETransferDetails(),
      BankTransferWire() => const GetBankTransferWireDetails(),
      OnlineBillPayment() => const GetOnlineBillPaymentDetails(),
      CanadaPost() => const GetCanadaPostDetails(),
      InstantSepa() => const GetInstantSepaDetails(),
      RegularSepa() => const GetRegularSepaDetails(),
      SpeiTransfer() => const GetSpeiTransferDetails(),
      CrIbanCrc() => const GetCrIbanCrcDetails(),
      CrIbanUsd() => const GetCrIbanUsdDetails(),
      Sinpe() => const GetSinpeDetails(),
      ArsBankTransfer() => const GetArsBankTransferDetails(),
      CopBankTransfer(:final bankCode, :final amountCop) =>
        GetCopBankTransferDetails(bankCode: bankCode, amountCop: amountCop),
    };

    final result = await _getFundingDetailsUsecase.execute(query);

    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        fundingDetails: value.fundingDetails,
        isLoadingFundingDetails: false,
      ),
      Err(:final failure) => state.copyWith(
        getFundingDetailsFailure: failure,
        isLoadingFundingDetails: false,
      ),
    });
  }

  Future<void> _onScamWarningConsentSubmitted(
    FundExchangeScamWarningConsentSubmitted event,
    Emitter<FundExchangeState> emit,
  ) async {
    emit(
      state.copyWith(
        submitScamWarningConsentFailure: null,
        isSubmittingScamWarningConsent: true,
      ),
    );

    final consent = await _registerResponsibilityConsentUsecase.execute(
      const RegisterResponsibilityConsentCommand(),
    );

    if (consent case Err(:final failure)) {
      emit(
        state.copyWith(
          submitScamWarningConsentFailure: failure,
          isSubmittingScamWarningConsent: false,
        ),
      );
      return;
    }

    // Fetch and update user summary to reflect consent.
    final summary = await _getFundExchangeUserSummaryUsecase.execute();

    switch (summary) {
      case Err(:final failure):
        emit(
          state.copyWith(
            submitScamWarningConsentFailure: failure,
            isSubmittingScamWarningConsent: false,
          ),
        );
        return;
      case Ok(:final value):
        emit(
          state.copyWith(
            userSummary: value,
            isSubmittingScamWarningConsent: false,
          ),
        );
    }

    // Re-dispatch the pending action now that consent is confirmed.
    // Clear the action first so shouldShowScamWarningConsent=false prevents
    // the consent check from triggering again on re-dispatch.
    final action = state.pendingConsentAction;
    emit(state.copyWith(pendingConsentAction: null));
    switch (action) {
      case PendingFundingDetailsAction(:final method):
        add(FundExchangeEvent.fundingDetailsRequested(fundingMethod: method));
      case PendingCopInputAction():
        add(
          const FundExchangeEvent.fundingInstitutionsRequested(
            jurisdiction: FundingJurisdiction.colombia,
          ),
        );
      case null:
        break;
    }
  }

  Future<void> _onScamWarningDismissed(
    FundExchangeScamWarningDismissed event,
    Emitter<FundExchangeState> emit,
  ) async {
    emit(state.copyWith(pendingConsentAction: null));
  }

  Future<void> _onPaymentLinkOpenRequested(
    FundExchangePaymentLinkOpenRequested event,
    Emitter<FundExchangeState> emit,
  ) async {
    // The button is disabled while a launch is in flight; this makes the
    // same guarantee independent of the UI.
    if (state.isOpeningPaymentLink) return;

    emit(
      state.copyWith(openPaymentLinkFailure: null, isOpeningPaymentLink: true),
    );

    final result = await _openFundingPaymentLinkUsecase.execute(
      OpenFundingPaymentLinkCommand(paymentLink: event.paymentLink),
    );

    emit(switch (result) {
      Ok() => state.copyWith(isOpeningPaymentLink: false),
      Err(:final failure) => state.copyWith(
        openPaymentLinkFailure: failure,
        isOpeningPaymentLink: false,
      ),
    });
  }

  Future<void> _onFundingDetailsErrorCleared(
    FundExchangeFundingDetailsErrorCleared event,
    Emitter<FundExchangeState> emit,
  ) async {
    emit(
      state.copyWith(
        getFundingDetailsFailure: null,
        listFundingInstitutionsFailure: null,
        fundingInstitutions: event.resetInstitutions
            ? null
            : state.fundingInstitutions,
      ),
    );
  }
}
