import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bitcoin_price/bitcoin_price.dart'
    show BitcoinPriceLocalizations;
import 'package:exchange/exchange.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bull_exchange/testing.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';

class _Preferences extends Mock implements Preferences {}

class _ExchangeBloc extends MockBloc<ExchangeEvent, ExchangeState>
    implements ExchangeBloc {}

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'test',
);

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

const _loaded = ExchangeLoaded(
  session: _session,
  summary: _summary,
  announcements: AnnouncementsShown([]),
  refresh: RefreshIdle(),
  dcaStop: DcaStopIdle(),
);

/// Trade has no tab bar or system back on iOS: every state must lead home.
Future<void> _expectExitLeadsHome(
  WidgetTester tester,
  ExchangeState state,
) async {
  final cubit = _ExchangeBloc();
  when(() => cubit.state).thenReturn(state);

  var exits = 0;
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ExchangeBloc>.value(value: cubit),
        BitcoinPriceFixture.chart(),
      ],
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        locale: const Locale('en'),
        localizationsDelegates: const [
          BitcoinPriceLocalizations.delegate,
          ExchangeLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: _dashboard(
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

ExchangeHomeScreen _dashboard({
  required List<Widget> homeCards,
  required VoidCallback onHomeRefresh,
  required VoidCallback onOpenSettings,
  required void Function(ExchangeHomeAction) onAction,
  required VoidCallback onExit,
  Future<void> Function()? refreshAccount,
}) => ExchangeHomeScreen(
  watchDashboard: ExchangeSessionScope.watchDashboard,
  exchange: () => locator<Exchange>(),
  preferences: () => locator<Preferences>(),
  brandAsset: Assets.logos.bbLogoSmall.path,
  settingsAsset: Assets.icons.settingsLine.path,
  refreshAccount: refreshAccount ?? () async {},
  stopDca: () async {},
  onOpenDca: () {},
  onWithdraw: () {},
  onHistory: () {},
  failureMessage: (context, failure) => failure.toTranslated(context),
  homeCards: homeCards,
  onHomeRefresh: onHomeRefresh,
  onOpenSettings: onOpenSettings,
  onAction: onAction,
  onExit: onExit,
);

void main() {
  setUp(() {
    locator.registerSingleton<Exchange>(exchangeForTesting());
    locator.registerSingleton<Preferences>(_Preferences());
    addTearDown(() async {
      await locator.unregister<Preferences>();
      await locator.unregister<Exchange>();
    });
  });
  testWidgets('initial account failure shows error and retry fetches again', (
    tester,
  ) async {
    final cubit = _ExchangeBloc();
    when(
      () => cubit.state,
    ).thenReturn(const ExchangeLoadFailed(_session, ExchangeNetworkFailure()));
    var refreshes = 0;
    await tester.pumpWidget(
      BlocProvider<ExchangeBloc>.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            BitcoinPriceLocalizations.delegate,
            ExchangeLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _dashboard(
              homeCards: const [],
              refreshAccount: () async => refreshes++,
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
    expect(refreshes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });
  testWidgets(
    'initial account load shows progress while no result is available',
    (tester) async {
      final cubit = _ExchangeBloc();
      when(() => cubit.state).thenReturn(const ExchangeLoading(_session));
      await tester.pumpWidget(
        BlocProvider<ExchangeBloc>.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            locale: const Locale('en'),
            localizationsDelegates: const [
              BitcoinPriceLocalizations.delegate,
              ExchangeLocalizations.delegate,
              ...AppLocalizations.localizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: _dashboard(
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
    final cubit = _ExchangeBloc();
    when(() => cubit.state).thenReturn(_loaded);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ExchangeBloc>.value(value: cubit),
          BitcoinPriceFixture.chart(),
        ],
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            BitcoinPriceLocalizations.delegate,
            ExchangeLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _dashboard(
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
      await _expectExitLeadsHome(tester, const ExchangeLoading(_session));
    });

    testWidgets('initial failure', (tester) async {
      await _expectExitLeadsHome(
        tester,
        const ExchangeLoadFailed(_session, ExchangeNetworkFailure()),
      );
    });

    testWidgets('loaded account', (tester) async {
      await _expectExitLeadsHome(tester, _loaded);
    });
  });
}
