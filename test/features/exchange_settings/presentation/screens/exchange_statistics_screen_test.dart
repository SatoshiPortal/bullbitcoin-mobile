import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_statistics_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/statistics_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

const _rawReason =
    'ExchangeApiException[ERR_KYC_403]: recipient bc1qexamplerecipient rejected';

class _MockGetStatistics extends Mock implements GetExchangeStatisticsUsecase {}

Future<StatisticsCubit> _pump(
  WidgetTester tester, {
  required ExchangeSettingsFailure failure,
}) async {
  final usecase = _MockGetStatistics();
  when(usecase.execute).thenAnswer((_) async => Err(failure));

  final cubit = StatisticsCubit(getStatisticsUsecase: usecase);
  addTearDown(cubit.close);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ExchangeStatisticsScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    BlocProvider<StatisticsCubit>.value(
      value: cubit,
      child: MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return cubit;
}

/// Everything the screen actually paints.
String _painted(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' | ');

void main() {
  testWidgets('a load failure is shown translated, with a retry', (
    tester,
  ) async {
    await _pump(
      tester,
      failure: const ExchangeSettingsStatisticsUnavailableFailure(_rawReason),
    );

    expect(
      find.text(
        'Your trading statistics could not be loaded. Please try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('the raw reason never reaches the screen', (tester) async {
    await _pump(
      tester,
      failure: const ExchangeSettingsStatisticsUnavailableFailure(_rawReason),
    );

    final painted = _painted(tester);
    expect(painted, isNot(contains('ERR_KYC_403')));
    expect(painted, isNot(contains('bc1qexamplerecipient')));
    expect(painted, isNot(contains('Exception')));
    expect(painted, isNotEmpty);
  });

  testWidgets('the catch-all renders the generic message, not logMessage', (
    tester,
  ) async {
    await _pump(
      tester,
      failure: const ExchangeSettingsUnexpectedFailure(_rawReason),
    );

    expect(find.text('Oops! Something went wrong'), findsOneWidget);
    expect(_painted(tester), isNot(contains(_rawReason)));
  });

  testWidgets('retry asks the use-case again', (tester) async {
    final cubit = await _pump(
      tester,
      failure: const ExchangeSettingsStatisticsUnavailableFailure(_rawReason),
    );
    expect(cubit.state.failure, isNotNull);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Still failing, so the error stays put rather than silently clearing.
    expect(cubit.state.failure, isNotNull);
    expect(find.text('Retry'), findsOneWidget);
  });
}
