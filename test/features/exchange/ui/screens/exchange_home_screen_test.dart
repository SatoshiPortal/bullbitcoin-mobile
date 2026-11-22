import 'package:bitcoin_price/bitcoin_price.dart'
    show BitcoinPriceLocalizations;
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/autobuy/public/autobuy_facade.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_home_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _ExchangeCubit extends MockCubit<ExchangeState>
    implements ExchangeCubit {}

class _AutoBuy extends Mock implements AutoBuyFacade {}

const _summary = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [],
  currency: 'CAD',
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

/// Trade has no tab bar or system back on iOS: every state must lead home.
Future<void> _expectExitLeadsHome(
  WidgetTester tester,
  ExchangeState state,
) async {
  final cubit = _ExchangeCubit();
  when(() => cubit.state).thenReturn(state);

  var exits = 0;
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ExchangeCubit>.value(value: cubit),
        BitcoinPriceFixture.chart(),
      ],
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        locale: const Locale('en'),
        localizationsDelegates: const [
          BitcoinPriceLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExchangeHomeScreen(
            homeCards: const [],
            onHomeRefresh: () {},
            onOpenSettings: () {},
            onAction: (_) {},
            onExit: () => exits++,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byType(BackButton));
  expect(exits, 1);
  await tester.pumpWidget(const SizedBox.shrink());
  await cubit.close();
}

void main() {
  testWidgets('initial account failure shows error and retry fetches again', (
    tester,
  ) async {
    final cubit = _ExchangeCubit();
    when(() => cubit.state).thenReturn(
      const ExchangeState(getUserSummaryFailure: ExchangeNetworkFailure()),
    );
    when(cubit.fetchUserSummary).thenAnswer((_) async {});
    await tester.pumpWidget(
      BlocProvider<ExchangeCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            BitcoinPriceLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ExchangeHomeScreen(
              homeCards: const [],
              onHomeRefresh: () {},
              onOpenSettings: () {},
              onAction: (_) {},
              onExit: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final loc = AppLocalizations.of(
      tester.element(find.byType(ExchangeHomeScreen)),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(loc.exchangeErrorNetwork), findsOneWidget);
    await tester.tap(find.text(loc.retry));
    verify(cubit.fetchUserSummary).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });
  testWidgets(
    'initial account load shows progress while no result is available',
    (tester) async {
      final cubit = _ExchangeCubit();
      when(() => cubit.state).thenReturn(const ExchangeState());
      await tester.pumpWidget(
        BlocProvider<ExchangeCubit>.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            locale: const Locale('en'),
            localizationsDelegates: const [
              BitcoinPriceLocalizations.delegate,
              ...AppLocalizations.localizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ExchangeHomeScreen(
                homeCards: const [],
                onHomeRefresh: () {},
                onOpenSettings: () {},
                onAction: (_) {},
                onExit: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
    },
  );

  testWidgets('names every top bar button within a 48 dp target', (
    tester,
  ) async {
    final autoBuy = _AutoBuy();
    when(
      () => autoBuy.buildHomeCard(
        isActive: any(named: 'isActive'),
        isRestricted: any(named: 'isRestricted'),
        onActivate: any(named: 'onActivate'),
        onStatusChanged: any(named: 'onStatusChanged'),
      ),
    ).thenReturn(const SizedBox.shrink());
    locator.registerSingleton<AutoBuyFacade>(autoBuy);
    addTearDown(() => locator.unregister<AutoBuyFacade>());
    final cubit = _ExchangeCubit();
    when(() => cubit.state)
        .thenReturn(const ExchangeState(userSummary: _summary));

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ExchangeCubit>.value(value: cubit),
          BitcoinPriceFixture.chart(),
        ],
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            BitcoinPriceLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ExchangeHomeScreen(
              homeCards: const [],
              onHomeRefresh: () {},
              onOpenSettings: () {},
              onAction: (_) {},
              onExit: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (final tooltip in [
      'Back',
      'Show price chart',
      'Transaction History',
      'Settings',
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
      final button = find
          .ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          )
          .first;
      expect(tester.getSize(button), const Size(48, 48), reason: tooltip);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });

  group('every Trade state leads back to Wallet Home', () {
    testWidgets('loading', (tester) async {
      await _expectExitLeadsHome(tester, const ExchangeState());
    });

    testWidgets('initial failure', (tester) async {
      await _expectExitLeadsHome(
        tester,
        const ExchangeState(getUserSummaryFailure: ExchangeNetworkFailure()),
      );
    });

    testWidgets('loaded account', (tester) async {
      final autoBuy = _AutoBuy();
      when(
        () => autoBuy.buildHomeCard(
          isActive: any(named: 'isActive'),
          isRestricted: any(named: 'isRestricted'),
          onActivate: any(named: 'onActivate'),
          onStatusChanged: any(named: 'onStatusChanged'),
        ),
      ).thenReturn(const SizedBox.shrink());
      locator.registerSingleton<AutoBuyFacade>(autoBuy);
      addTearDown(() => locator.unregister<AutoBuyFacade>());
      await _expectExitLeadsHome(
        tester,
        const ExchangeState(userSummary: _summary),
      );
    });
  });
}
