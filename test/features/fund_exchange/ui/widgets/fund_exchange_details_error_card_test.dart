import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_confidential_sepa_funding_availability_usecase.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullInfoCard;
import 'package:bb_mobile/features/fund_exchange/domain/external_link_port.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_fund_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/open_funding_payment_link_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

const _rawReason =
    'getUserPaymentProcessorCode API error [ERR_ORD_KYC400]: '
    'Missing fields for DE89370400440532013000';

class _MockGetUserSummary extends Mock
    implements GetFundExchangeUserSummaryUsecase {}

/// Returns [failure] for every funding-details request, so the bloc lands in
/// the error state the card renders.
class _FailingRepository implements ExchangeFunding {
  final ExchangeFailure failure;

  const _FailingRepository(this.failure);

  @override
  Future<Result<FundingDetails, ExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async => Err(failure);

  @override
  Future<Result<List<FundingInstitution>, ExchangeFailure>> listInstitutions({
    required FundingJurisdiction jurisdiction,
  }) async => Err(failure);

  @override
  Future<Result<void, ExchangeFailure>> registerResponsibilityConsent() async =>
      Err(failure);
}

FundExchangeBloc _blocFor(ExchangeFailure failure) {
  final repository = _FailingRepository(failure);
  return FundExchangeBloc(
    getFundExchangeUserSummaryUsecase: _MockGetUserSummary(),
    getFundingDetailsUsecase: GetFundingDetailsUsecase(funding: repository),
    listFundingInstitutionsUsecase: ListFundingInstitutionsUsecase(
      funding: repository,
    ),
    registerResponsibilityConsentUsecase: RegisterResponsibilityConsentUsecase(
      funding: repository,
    ),
    openFundingPaymentLinkUsecase: const OpenFundingPaymentLinkUsecase(
      externalLink: _UnusedExternalLink(),
    ),
    getConfidentialSepaFundingAvailabilityUsecase: _NoConfidentialSepa(),
  );
}

/// The card under test never opens a link; this satisfies the bloc's
/// dependency without pulling in a platform channel.
class _UnusedExternalLink implements ExternalLinkPort {
  const _UnusedExternalLink();

  @override
  Future<Result<void, FundExchangeFailure>> open(Uri url) async =>
      throw UnimplementedError();
}

Future<BullInfoCard> _pumpCard(
  WidgetTester tester,
  ExchangeFailure failure, {
  bool triggerFailure = true,
}) async {
  late final FundExchangeBloc bloc;
  await tester.runAsync(() async {
    bloc = _blocFor(failure);
    addTearDown(bloc.close);
    if (triggerFailure) {
      final failed = bloc.stream.firstWhere(
        (state) => state.getFundingDetailsFailure != null,
      );
      bloc.add(
        FundExchangeEvent.fundingDetailsRequested(fundingMethod: RegularSepa()),
      );
      await failed;
    }
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<FundExchangeBloc>.value(
          value: bloc,
          child: const FundExchangeDetailsErrorCard(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return tester.widget<BullInfoCard>(find.byType(BullInfoCard));
}

class _NoConfidentialSepa
    implements GetConfidentialSepaFundingAvailabilityUsecase {
  @override
  Future<Result<bool, FundExchangeFailure>> execute() async => const Ok(false);
}

void main() {
  testWidgets('shows the failure headline and message', (tester) async {
    final card = await _pumpCard(
      tester,
      const ExchangeFundingFailure(
        ExchangeFundingProblem.kycIncomplete,
        _rawReason,
      ),
    );

    expect(card.title, 'KYC Requirements Missing');
    expect(
      card.description,
      'You do not have the KYC requirements for this action',
    );
  });

  testWidgets('falls back to the generic message with no failure', (
    tester,
  ) async {
    final card = await _pumpCard(
      tester,
      const ExchangeUnexpectedFailure(),
      triggerFailure: false,
    );

    expect(card.title, isNull);
    expect(card.description, isNotEmpty);
  });

  testWidgets('the catch-all names the details load, not the shared generic', (
    tester,
  ) async {
    final card = await _pumpCard(
      tester,
      const ExchangeUnexpectedFailure(_rawReason),
    );

    expect(card.title, isNull);
    expect(
      card.description,
      startsWith('The payment details could not be loaded'),
    );
  });

  testWidgets('never renders the raw reason', (tester) async {
    final card = await _pumpCard(
      tester,
      const ExchangeUnexpectedFailure(_rawReason),
    );

    final painted = '${card.title} ${card.description}';
    expect(painted, isNot(contains('ERR_')));
    expect(painted, isNot(contains('DE89370400440532013000')));
    expect(painted, isNot(contains('API error')));
    expect(card.description, isNotEmpty);
  });
}
