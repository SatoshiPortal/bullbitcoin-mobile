import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_fund_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
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
class _FailingGateway implements FundingGatewayPort {
  final FundExchangeFailure failure;

  const _FailingGateway(this.failure);

  @override
  Future<Result<FundingDetails, FundExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async => Err(failure);

  @override
  Future<Result<List<FundingInstitution>, FundExchangeFailure>>
  listInstitutions({required FundingJurisdiction jurisdiction}) async =>
      Err(failure);

  @override
  Future<Result<void, FundExchangeFailure>>
  registerResponsibilityConsent() async => Err(failure);
}

FundExchangeBloc _blocFor(FundExchangeFailure failure) {
  final gateway = _FailingGateway(failure);
  return FundExchangeBloc(
    getFundExchangeUserSummaryUsecase: _MockGetUserSummary(),
    getFundingDetailsUsecase: GetFundingDetailsUsecase(fundingGateway: gateway),
    listFundingInstitutionsUsecase: ListFundingInstitutionsUsecase(
      fundingGateway: gateway,
    ),
    registerResponsibilityConsentUsecase: RegisterResponsibilityConsentUsecase(
      fundingGateway: gateway,
    ),
  );
}

Future<InfoCard> _pumpCard(
  WidgetTester tester,
  FundExchangeBloc bloc, {
  bool triggerFailure = true,
}) async {
  addTearDown(bloc.close);
  if (triggerFailure) {
    bloc.add(
      FundExchangeEvent.fundingDetailsRequested(fundingMethod: RegularSepa()),
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  return tester.widget<InfoCard>(find.byType(InfoCard));
}

void main() {
  testWidgets('shows the failure headline and message', (tester) async {
    final card = await _pumpCard(
      tester,
      _blocFor(const FundExchangeKycIncompleteFailure(_rawReason)),
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
      _blocFor(const FundExchangeUnexpectedFailure()),
      triggerFailure: false,
    );

    expect(card.title, isNull);
    expect(card.description, isNotEmpty);
  });

  testWidgets('never renders the raw reason', (tester) async {
    final card = await _pumpCard(
      tester,
      _blocFor(const FundExchangeUnexpectedFailure(_rawReason)),
    );

    final painted = '${card.title} ${card.description}';
    expect(painted, isNot(contains('ERR_')));
    expect(painted, isNot(contains('DE89370400440532013000')));
    expect(painted, isNot(contains('API error')));
    expect(card.description, isNotEmpty);
  });
}
