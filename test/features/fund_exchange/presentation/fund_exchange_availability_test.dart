import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_fund_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/open_funding_payment_link_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/get_confidential_sepa_funding_availability_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_method_selection_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullFadingLinearProgress;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetUserSummary extends Mock
    implements GetFundExchangeUserSummaryUsecase {}

class _MockGetFundingDetails extends Mock implements GetFundingDetailsUsecase {}

class _MockListInstitutions extends Mock
    implements ListFundingInstitutionsUsecase {}

class _MockRegisterConsent extends Mock
    implements RegisterResponsibilityConsentUsecase {}

class _MockOpenPaymentLink extends Mock
    implements OpenFundingPaymentLinkUsecase {}

class _MockGetAvailability extends Mock
    implements GetConfidentialSepaFundingAvailabilityUsecase {}

const _summary = UserSummary(
  userNumber: 1,
  groups: ['KYC_IDENTITY_VERIFIED', 'JURI_EU', 'CONSENT_SCAM_WARNING'],
  profile: UserProfile(firstName: 'Satoshi', lastName: 'Nakamoto'),
  email: 'test@example.com',
  balances: [],
  currency: 'EUR',
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

void main() {
  late _MockGetAvailability getAvailability;
  late FundExchangeBloc bloc;

  setUp(() {
    getAvailability = _MockGetAvailability();
    final getSummary = _MockGetUserSummary();
    when(
      () => getSummary.execute(),
    ).thenAnswer((_) async => const Ok(_summary));
    when(
      () => getAvailability.execute(),
    ).thenAnswer((_) async => const Err(FundExchangeNetworkFailure()));
    bloc = FundExchangeBloc(
      getFundExchangeUserSummaryUsecase: getSummary,
      getFundingDetailsUsecase: _MockGetFundingDetails(),
      listFundingInstitutionsUsecase: _MockListInstitutions(),
      registerResponsibilityConsentUsecase: _MockRegisterConsent(),
      openFundingPaymentLinkUsecase: _MockOpenPaymentLink(),
      getConfidentialSepaFundingAvailabilityUsecase: getAvailability,
    );
    addTearDown(bloc.close);
  });

  test(
    'a failed check can recover without concurrent retry requests',
    () async {
      bloc.add(const FundExchangeEvent.started());
      await pumpEventQueue();

      expect(bloc.state.isStarted, isTrue);
      expect(bloc.state.isConfidentialSepaAvailable, isFalse);
      expect(
        bloc.state.confidentialSepaAvailabilityFailure,
        isA<FundExchangeNetworkFailure>(),
      );

      final retry = Completer<Result<bool, FundExchangeFailure>>();
      when(() => getAvailability.execute()).thenAnswer((_) => retry.future);
      bloc.add(const FundExchangeEvent.confidentialSepaAvailabilityRetried());
      bloc.add(const FundExchangeEvent.confidentialSepaAvailabilityRetried());
      await pumpEventQueue();

      expect(bloc.state.isLoadingConfidentialSepaAvailability, isTrue);
      expect(bloc.state.confidentialSepaAvailabilityFailure, isNull);
      verify(() => getAvailability.execute()).called(2);

      retry.complete(const Ok(true));
      await pumpEventQueue();

      expect(bloc.state.isConfidentialSepaAvailable, isTrue);
      expect(bloc.state.isLoadingConfidentialSepaAvailability, isFalse);
      expect(bloc.state.confidentialSepaAvailabilityFailure, isNull);
      expect(bloc.state.userSummary, _summary);
    },
  );

  test('confirmed ineligibility does not show an error', () async {
    when(
      () => getAvailability.execute(),
    ).thenAnswer((_) async => const Ok(false));
    bloc.add(const FundExchangeEvent.started());
    await pumpEventQueue();

    expect(bloc.state.isStarted, isTrue);
    expect(bloc.state.isConfidentialSepaAvailable, isFalse);
    expect(bloc.state.confidentialSepaAvailabilityFailure, isNull);
    expect(bloc.state.isLoadingConfidentialSepaAvailability, isFalse);
  });

  test(
    'a repeated failure stays retryable and ineligibility clears it',
    () async {
      bloc.add(const FundExchangeEvent.started());
      await pumpEventQueue();
      bloc.add(const FundExchangeEvent.confidentialSepaAvailabilityRetried());
      await pumpEventQueue();

      expect(
        bloc.state.confidentialSepaAvailabilityFailure,
        isA<FundExchangeNetworkFailure>(),
      );
      expect(bloc.state.isLoadingConfidentialSepaAvailability, isFalse);

      when(
        () => getAvailability.execute(),
      ).thenAnswer((_) async => const Ok(false));
      bloc.add(const FundExchangeEvent.confidentialSepaAvailabilityRetried());
      await pumpEventQueue();

      expect(bloc.state.isConfidentialSepaAvailable, isFalse);
      expect(bloc.state.confidentialSepaAvailabilityFailure, isNull);
      expect(bloc.state.isLoadingConfidentialSepaAvailability, isFalse);
    },
  );

  test(
    'closing the bloc while checking availability ignores the result',
    () async {
      final check = Completer<Result<bool, FundExchangeFailure>>();
      when(() => getAvailability.execute()).thenAnswer((_) => check.future);
      bloc.add(const FundExchangeEvent.started());
      await pumpEventQueue();

      final closing = bloc.close();
      check.complete(const Ok(true));
      await closing;

      expect(bloc.state.isConfidentialSepaAvailable, isFalse);
    },
  );

  testWidgets('shows a generic error and retry restores the funding option', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<FundExchangeBloc>.value(
          value: bloc,
          child: const FundExchangeMethodSelectionScreen(),
        ),
      ),
    );
    final loc = AppLocalizations.of(
      tester.element(find.byType(FundExchangeMethodSelectionScreen)),
    );
    bloc.add(const FundExchangeEvent.started());
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        '${loc.oopsSomethingWentWrong}\n${loc.fundExchangeErrorNetwork}',
      ),
      findsOneWidget,
    );
    expect(find.text(loc.fundExchangeMethodConfidentialSepa), findsNothing);
    expect(find.text(loc.fundExchangeMethodRegularSepa), findsOneWidget);

    final retry = Completer<Result<bool, FundExchangeFailure>>();
    when(() => getAvailability.execute()).thenAnswer((_) => retry.future);
    await tester.ensureVisible(find.text(loc.retry));
    await tester.tap(find.text(loc.retry));
    await tester.pump();

    expect(bloc.state.isLoadingConfidentialSepaAvailability, isTrue);
    expect(find.text(loc.fundExchangeMethodRegularSepa), findsOneWidget);
    expect(find.byType(BullFadingLinearProgress), findsOneWidget);
    expect(
      tester
          .widget<BullFadingLinearProgress>(
            find.byType(BullFadingLinearProgress),
          )
          .trigger,
      isTrue,
    );

    retry.complete(const Ok(true));
    await tester.pump();
    await tester.pump();

    expect(find.text(loc.fundExchangeMethodConfidentialSepa), findsOneWidget);
    expect(find.text(loc.retry), findsNothing);
  });
}
