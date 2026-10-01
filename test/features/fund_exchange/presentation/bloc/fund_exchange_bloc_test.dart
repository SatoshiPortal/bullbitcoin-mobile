import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_error.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/pending_consent_action.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart'
    show VirtualIban, VirtualIbanStatus;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockGetFundingDetailsUsecase extends Mock
    implements GetFundingDetailsUsecase {}

class _MockGetVirtualIbanUsecase extends Mock
    implements GetVirtualIbanUsecase {}

class _MockListFundingInstitutionsUsecase extends Mock
    implements ListFundingInstitutionsUsecase {}

class _MockRegisterResponsibilityConsentUsecase extends Mock
    implements RegisterResponsibilityConsentUsecase {}

void main() {
  late _MockGetExchangeUserSummaryUsecase getUserSummary;
  late _MockGetFundingDetailsUsecase getFundingDetails;
  late _MockGetVirtualIbanUsecase getVirtualIban;
  late _MockListFundingInstitutionsUsecase listInstitutions;
  late _MockRegisterResponsibilityConsentUsecase registerConsent;

  UserSummary userSummary({List<String> groups = const []}) => UserSummary(
    userNumber: 1,
    groups: groups,
    profile: const UserProfile(firstName: 'Sat', lastName: 'Oshi'),
    email: 'sat@example.com',
    balances: const [],
    dca: const UserDca(isActive: false),
    autoBuy: const UserAutoBuy(
      isActive: false,
      addresses: UserAutoBuyAddresses(),
    ),
  );

  final consentedUserSummary = userSummary(
    groups: const ['KYC_IDENTITY_VERIFIED', 'CONSENT_SCAM_WARNING'],
  );

  const activeVirtualIban = VirtualIban(
    status: VirtualIbanStatus.active,
    iban: 'DE89370400440532013000',
    bicCode: 'TESTBIC',
    bankAddress: 'Test bank address',
    ibanCountry: 'DE',
  );

  setUp(() {
    getUserSummary = _MockGetExchangeUserSummaryUsecase();
    getFundingDetails = _MockGetFundingDetailsUsecase();
    getVirtualIban = _MockGetVirtualIbanUsecase();
    listInstitutions = _MockListFundingInstitutionsUsecase();
    registerConsent = _MockRegisterResponsibilityConsentUsecase();
  });

  Future<FundExchangeBloc> startedBloc(UserSummary summary) async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => summary);
    final bloc = FundExchangeBloc(
      getExchangeUserSummaryUsecase: getUserSummary,
      getFundingDetailsUsecase: getFundingDetails,
      getVirtualIbanUsecase: getVirtualIban,
      listFundingInstitutionsUsecase: listInstitutions,
      registerResponsibilityConsentUsecase: registerConsent,
    );
    addTearDown(bloc.close);
    bloc.add(const FundExchangeEvent.started());
    await bloc.stream.firstWhere((state) => state.isStarted);
    return bloc;
  }

  group('confidential sepa funding details', () {
    test('emits funding details built from an active virtual IBAN', () async {
      when(
        () => getVirtualIban.execute(),
      ).thenAnswer((_) async => activeVirtualIban);
      final bloc = await startedBloc(consentedUserSummary);

      bloc.add(
        const FundExchangeEvent.fundingDetailsRequested(
          fundingMethod: ConfidentialSepa(),
        ),
      );
      await bloc.stream.firstWhere((state) => state.fundingDetails != null);

      final details =
          bloc.state.fundingDetails! as ConfidentialSepaFundingDetails;
      expect(details.iban, activeVirtualIban.iban);
      expect(details.recipientName, 'Sat Oshi');
      expect(details.bankAddress, activeVirtualIban.bankAddress);
      expect(details.bankAccountCountry, activeVirtualIban.ibanCountry);
      expect(details.bic, activeVirtualIban.bicCode);
      expect(bloc.state.virtualIban, isNull);
      verifyZeroInteractions(getFundingDetails);
    });

    test('exposes the virtual IBAN when it is not active yet', () async {
      when(
        () => getVirtualIban.execute(),
      ).thenAnswer((_) async => const VirtualIban.absent());
      final bloc = await startedBloc(consentedUserSummary);

      bloc.add(
        const FundExchangeEvent.fundingDetailsRequested(
          fundingMethod: ConfidentialSepa(),
        ),
      );
      await bloc.stream.firstWhere((state) => state.virtualIban != null);

      expect(bloc.state.virtualIban?.status, VirtualIbanStatus.absent);
      expect(bloc.state.fundingDetails, isNull);
    });

    test('surfaces the PO404 permission error', () async {
      when(() => getVirtualIban.execute()).thenThrow(
        const FetchFundingDetailsFailed(
          code: 'ERR_RCP_PO404',
          message: 'denied',
        ),
      );
      final bloc = await startedBloc(consentedUserSummary);

      bloc.add(
        const FundExchangeEvent.fundingDetailsRequested(
          fundingMethod: ConfidentialSepa(),
        ),
      );
      await bloc.stream.firstWhere(
        (state) => state.getExchangeFundingDetailsException != null,
      );

      final error = bloc.state.getExchangeFundingDetailsException;
      expect(error, isA<FundExchangeApiError>());
      expect((error! as FundExchangeApiError).code, 'ERR_RCP_PO404');
    });

    test('gates the request behind the scam warning consent', () async {
      final bloc = await startedBloc(
        userSummary(groups: const ['KYC_IDENTITY_VERIFIED']),
      );

      bloc.add(
        const FundExchangeEvent.fundingDetailsRequested(
          fundingMethod: ConfidentialSepa(),
        ),
      );
      await bloc.stream.firstWhere(
        (state) => state.pendingConsentAction != null,
      );

      expect(
        bloc.state.pendingConsentAction,
        const PendingFundingDetailsAction(ConfidentialSepa()),
      );
      verifyZeroInteractions(getVirtualIban);
    });
  });

  group('canShowConfidentialSepa', () {
    test('is true for a non-corporate user', () {
      final state = FundExchangeState(userSummary: consentedUserSummary);
      expect(state.canShowConfidentialSepa, isTrue);
    });

    test('is false for a corporate user or before the summary loads', () {
      final corporate = userSummary(
        groups: const ['KYC_IDENTITY_VERIFIED', 'KYC_IS_CORPORATE'],
      );
      expect(
        FundExchangeState(userSummary: corporate).canShowConfidentialSepa,
        isFalse,
      );
      expect(const FundExchangeState().canShowConfidentialSepa, isFalse);
    });
  });
}
