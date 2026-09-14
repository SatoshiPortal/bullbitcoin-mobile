import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/external_link_port.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_fund_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/open_funding_payment_link_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_cop_bank_transfer_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

const _link = 'https://pay.example.com/abc';
const _copMethod = CopBankTransfer(bankCode: 'BC01', amountCop: 50000);

class _MockGetUserSummary extends Mock
    implements GetFundExchangeUserSummaryUsecase {}

/// Serves the COP payment link so the screen reaches its success layout.
class _CopGateway implements FundingGatewayPort {
  const _CopGateway();

  @override
  Future<Result<FundingDetails, FundExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async => const Ok(CopBankTransferFundingDetails(paymentLink: _link));

  @override
  Future<Result<List<FundingInstitution>, FundExchangeFailure>>
  listInstitutions({required FundingJurisdiction jurisdiction}) async =>
      throw UnimplementedError();

  @override
  Future<Result<void, FundExchangeFailure>>
  registerResponsibilityConsent() async => throw UnimplementedError();
}

/// Holds the launch open until released, so the in-flight state is observable.
class _BlockingExternalLink implements ExternalLinkPort {
  final List<Uri> opened = [];
  final List<Completer<Result<void, FundExchangeFailure>>> pending = [];

  @override
  Future<Result<void, FundExchangeFailure>> open(Uri url) {
    opened.add(url);
    final completer = Completer<Result<void, FundExchangeFailure>>();
    pending.add(completer);
    return completer.future;
  }

  void releaseAll() {
    for (final completer in pending) {
      if (!completer.isCompleted) completer.complete(const Ok(null));
    }
  }
}

/// Fails every launch, so the error path can be rendered.
class _FailingExternalLink implements ExternalLinkPort {
  const _FailingExternalLink();

  @override
  Future<Result<void, FundExchangeFailure>> open(Uri url) async =>
      const Err(FundExchangePaymentLinkUnavailableFailure('PlatformException'));
}

FundExchangeBloc _blocWith(ExternalLinkPort link) {
  const gateway = _CopGateway();
  return FundExchangeBloc(
    getFundExchangeUserSummaryUsecase: _MockGetUserSummary(),
    getFundingDetailsUsecase: const GetFundingDetailsUsecase(
      fundingGateway: gateway,
    ),
    listFundingInstitutionsUsecase: const ListFundingInstitutionsUsecase(
      fundingGateway: gateway,
    ),
    registerResponsibilityConsentUsecase:
        const RegisterResponsibilityConsentUsecase(fundingGateway: gateway),
    openFundingPaymentLinkUsecase: OpenFundingPaymentLinkUsecase(
      externalLink: link,
    ),
  );
}

/// Pumps the screen with the payment link already loaded.
Future<void> _pumpLoaded(WidgetTester tester, ExternalLinkPort link) async {
  final bloc = _blocWith(link);
  // `close()` waits for in-flight event handlers. A launch parked on a
  // Completer must therefore be released *inside* the test body — tear-downs
  // run outside the FakeAsync zone, so completing one there never advances the
  // microtask that would finish the handler, and the test hangs.
  addTearDown(bloc.close);
  bloc.add(
    const FundExchangeEvent.fundingDetailsRequested(fundingMethod: _copMethod),
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const FundExchangeCopBankTransferScreen(),
      ),
      GoRoute(
        name: ExchangeRoute.exchangeHome.name,
        path: '/exchange-home',
        builder: (context, state) => const Text('exchange home'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    BlocProvider<FundExchangeBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The "open payment link" button, as opposed to the "done" bar button.
BBButton _openButton(WidgetTester tester) => tester
    .widgetList<BBButton>(find.byType(BBButton))
    .firstWhere((b) => b.iconData == Icons.open_in_new);

void main() {
  testWidgets('the open button is enabled once the link has loaded', (
    tester,
  ) async {
    final link = _BlockingExternalLink();
    await _pumpLoaded(tester, link);

    expect(_openButton(tester).disabled, isFalse);
  });

  testWidgets('the open button is disabled while a launch is in flight', (
    tester,
  ) async {
    final link = _BlockingExternalLink();
    await _pumpLoaded(tester, link);

    await tester.tap(find.byIcon(Icons.open_in_new));
    await tester.pump();

    expect(
      _openButton(tester).disabled,
      isTrue,
      reason: 'isOpeningPaymentLink must reach the button',
    );
    expect(link.opened.single.toString(), _link);

    link.releaseAll();
    await tester.pumpAndSettle();
  });

  testWidgets('a second tap while in flight does not open the link twice', (
    tester,
  ) async {
    final link = _BlockingExternalLink();
    await _pumpLoaded(tester, link);

    await tester.tap(find.byIcon(Icons.open_in_new));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.open_in_new), warnIfMissed: false);
    await tester.pump();

    expect(link.opened, hasLength(1));

    link.releaseAll();
    await tester.pumpAndSettle();
  });

  testWidgets('the button is re-enabled once the launch settles', (
    tester,
  ) async {
    final link = _BlockingExternalLink();
    await _pumpLoaded(tester, link);

    await tester.tap(find.byIcon(Icons.open_in_new));
    await tester.pump();
    link.pending.single.complete(const Ok(null));
    await tester.pumpAndSettle();

    expect(_openButton(tester).disabled, isFalse);
  });

  testWidgets('a failed launch is shown to the user, sanitized', (
    tester,
  ) async {
    await _pumpLoaded(tester, const _FailingExternalLink());

    await tester.tap(find.byIcon(Icons.open_in_new));
    await tester.pumpAndSettle();

    expect(
      find.text('The payment link could not be opened. Please try again.'),
      findsOneWidget,
    );

    final painted = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' | ');
    expect(painted, isNot(contains('PlatformException')));
    // The button must come back, or the user is stuck with no way to retry.
    expect(_openButton(tester).disabled, isFalse);
  });
}
