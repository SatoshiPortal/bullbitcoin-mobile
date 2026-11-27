import 'package:bull_exchange/bull_exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/testing.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:primitives/primitives.dart' show BitcoinUnit, Ok;
import 'package:transactions/routes.dart' show TransactionsRoute;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:exchange/setup.dart' show ExchangeAccessLifecycle;
import 'package:exchange/testing.dart' show exchangeForTesting;
import 'package:exchange/exchange.dart';
import 'package:settings/testing.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_webview_platform.dart';

const _testSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'test',
);

class _Exchange extends Mock implements ExchangeAccessLifecycle {}

class _Settings extends MockCubit<SettingsState> implements SettingsCubit {}

class _ExchangeBloc extends MockBloc<ExchangeEvent, ExchangeState>
    implements ExchangeBloc {}

List<RouteBase> _mountSettings(Exchange exchange) => BullExchangeFeature.mount(
  exchange: () => exchange,
  preferences: () => fail('No Preferences read needed on this route'),
  isSuperuser: (_) => false,
  homePath: WalletRoute.walletHome.path,
  onExit: AppRouter.exitExchange,
  onOpenSettings: (_) {},
  onAction: (_, _) {},
  brandAssetPath: 'unused',
  settingsAssetPath: 'unused',
  settings: AppRouter.exchangeSettingsHost,
).settingsRoutes;

SettingsState _settingsState(Environment environment) => SettingsState(
  storedSettings: SettingsEntity(
    environment: environment,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    isSuperuser: true,
  ),
);

void main() {
  testWidgets('sign-in from manage access returns to the same route', (
    tester,
  ) async {
    final exchange = _Exchange();
    final settings = _Settings();
    when(() => exchange.current)
        .thenReturn(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    when(exchange.watch).thenAnswer((_) => const Stream.empty());
    when(() => settings.state).thenReturn(const SettingsState());
    locator.registerSingleton<Exchange>(exchangeForTesting(access: exchange));
    addTearDown(() => locator.unregister<Exchange>());
    final manage =
        BullExchangeFeature.mount(
          exchange: () => locator<Exchange>(),
          preferences: () => throw StateError('Unexpected preferences'),
          isSuperuser: (_) => false,
          homePath: '/home',
          onExit: (_) {},
          onOpenSettings: (_) {},
          onAction: (_, _) {},
          brandAssetPath: 'unused',
          settingsAssetPath: 'unused',
          settings: AppRouter.exchangeSettingsHost,
        ).settingsRoutes.whereType<GoRoute>().singleWhere(
          (route) => route.name == ExchangeAccessSettingsNavigation.name,
        );
    final router = GoRouter(
      initialLocation: '/manage',
      routes: [
        GoRoute(path: '/manage', builder: manage.builder),
        GoRoute(
          path: '/auth',
          name: BullExchangeNavigation.authName,
          builder: (context, state) {
            expect(state.uri.queryParameters['from'], 'settings');
            return Scaffold(
              body: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Return'),
              ),
            );
          },
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: settings,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Navigator).first);
    final signIn = ExchangeLocalizations.of(context).exchangeAccessSignIn;
    await tester.tap(find.text(signIn));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return'));
    await tester.pumpAndSettle();
    expect(find.text(signIn), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await settings.close();
  });

  testWidgets('real manage route reaches account settings and security route', (
    tester,
  ) async {
    final exchange = _Exchange();
    final settings = _Settings();
    final exchangeCubit = _ExchangeBloc();
    when(() => exchangeCubit.state)
        .thenReturn(const ExchangeLoading(_testSession));
    when(() => settings.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isSuperuser: true,
        ),
      ),
    );
    when(() => exchange.current)
        .thenReturn(const ExchangeAccessSignedIn(_testSession));
    when(exchange.watch).thenAnswer((_) => const Stream.empty());
    locator.registerSingleton<Exchange>(exchangeForTesting(access: exchange));
    addTearDown(() => locator.unregister<Exchange>());
    final settingsRoutes = AppRouter.settingsChildren(
      quickActions: () => fail('Unexpected Quick Actions resolution'),
      swapRecoveryRoutes: const [],
      accessRoutes: const [],
      addressRoutes: const [],
      exchangeSettingsRoutes: BullExchangeFeature.mount(
        exchange: () => locator<Exchange>(),
        preferences: () => throw StateError('Unexpected preferences'),
        isSuperuser: (_) => false,
        homePath: '/home',
        onExit: (_) {},
        onOpenSettings: (_) {},
        onAction: (_, _) {},
        brandAssetPath: 'unused',
        settingsAssetPath: 'unused',
        settings: AppRouter.exchangeSettingsHost,
      ).settingsRoutes,
      backupRoutes: const [],
      priceRoutes: const [],
      walletRoutes: const [],
    );
    final manage = settingsRoutes.whereType<GoRoute>().singleWhere(
      (route) => route.name == ExchangeAccessSettingsNavigation.name,
    );
    final account = settingsRoutes.whereType<GoRoute>().singleWhere(
      (route) => route.name == ExchangeSettingsRoute.home.name,
    );
    final router = GoRouter(
      initialLocation: '/manage',
      routes: [
        GoRoute(
          path: '/manage',
          name: ExchangeAccessSettingsNavigation.name,
          builder: manage.builder,
        ),
        GoRoute(
          path: '/account',
          name: ExchangeSettingsRoute.home.name,
          builder: account.builder,
        ),
        GoRoute(
          path: '/exchange',
          name: BullExchangeNavigation.dashboardName,
          builder: (_, _) => const Scaffold(body: Text('Exchange dashboard')),
        ),
        GoRoute(
          path: '/security',
          name: ExchangeSettingsRoute.security.name,
          builder: (_, _) => const Scaffold(body: Text('Security destination')),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settings),
          BlocProvider<ExchangeBloc>.value(value: exchangeCubit),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    var context = tester.element(
      find.byWidgetPredicate((widget) => widget is Navigator).first,
    );
    final accessTitle = ExchangeLocalizations.of(context)
        .exchangeAccessSettingsTitle;
    expect(find.text(accessTitle), findsOneWidget);
    await tester.tap(
      find.text(ExchangeLocalizations.of(context).settingsAccountSettingsTitle),
    );
    await tester.pumpAndSettle();
    context = tester.element(find.byType(ExchangeSettingsScreen));
    await tester.tap(
      find.text(
        AppLocalizations.of(context).exchangeSettingsSecuritySettingsTitle,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Security destination'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await settings.close();
    await exchangeCubit.close();
  });
  testWidgets('route rebuild retains one owned cubit and closes it on exit', (
    tester,
  ) async {
    final exchange = _Exchange();
    final settings = _Settings();
    when(() => settings.state).thenReturn(const SettingsState());
    when(() => exchange.current).thenReturn(const ExchangeAccessDisabled());
    var listens = 0;
    var cancels = 0;
    final changes = StreamController<ExchangeAccess>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    when(exchange.watch).thenAnswer((_) => changes.stream);
    locator.registerSingleton<Exchange>(exchangeForTesting(access: exchange));
    addTearDown(() => locator.unregister<Exchange>());
    final route =
        BullExchangeFeature.mount(
          exchange: () => locator<Exchange>(),
          preferences: () => throw StateError('Unexpected preferences'),
          isSuperuser: (_) => false,
          homePath: '/home',
          onExit: (_) {},
          onOpenSettings: (_) {},
          onAction: (_, _) {},
          brandAssetPath: 'unused',
          settingsAssetPath: 'unused',
          settings: AppRouter.exchangeSettingsHost,
        ).settingsRoutes.whereType<GoRoute>().singleWhere(
          (route) => route.name == ExchangeAccessSettingsNavigation.name,
        );
    final routeBuilder = route.builder;
    expect(routeBuilder, isNotNull);
    if (routeBuilder == null) throw StateError('Manage access needs a builder');
    final refresh = ValueNotifier(0);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/manage',
          builder: (context, state) => ValueListenableBuilder<int>(
            valueListenable: refresh,
            builder: (context, _, _) => routeBuilder(context, state),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: settings,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/manage');
    await tester.pumpAndSettle();
    expect(listens, 1);
    refresh.value++;
    await tester.pumpAndSettle();
    expect(listens, 1);
    expect(cancels, 0);
    router.pop();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    expect(cancels, 1);
    await changes.close();
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    refresh.dispose();
    await settings.close();
  });

  testWidgets('security uses the live Settings environment and its real URL', (
    tester,
  ) async {
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = FakeWebViewPlatform();
    addTearDown(() {
      if (previous != null) WebViewPlatform.instance = previous;
      FakeWebViewPlatform.lastController = null;
    });
    final settings = _Settings();
    final changes = StreamController<SettingsState>();
    whenListen(
      settings,
      changes.stream,
      initialState: _settingsState(Environment.mainnet),
    );
    final router = GoRouter(
      initialLocation: '/settings/exchange-security',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SizedBox.shrink(),
          routes: _mountSettings(exchangeForTesting()),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(changes.close);
    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: settings,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Navigator).first);
    final access = find.text(
      ExchangeLocalizations.of(context).exchangeSecurityAccessSettingsButton,
    );
    for (final (state, expected) in [
      (_settingsState(Environment.mainnet), ExchangeDefaults.bbAuthUrl),
      (_settingsState(Environment.testnet), ExchangeDefaults.bbAuthTestUrl),
      (_settingsState(Environment.regtest), null),
      (const SettingsState(), null),
    ]) {
      changes.add(state);
      await tester.pumpAndSettle();
      FakeWebViewPlatform.lastController = null;
      await tester.tap(access);
      await tester.pumpAndSettle();
      expect(
        FakeWebViewPlatform.lastController?.loadedUri,
        expected == null ? null : Uri.parse(expected).resolve('/settings'),
      );
      if (expected != null) {
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await settings.close();
  });

  testWidgets('Pay and exchange-only history push; disabling goes to Wallet', (
    tester,
  ) async {
    final lifecycle = _Exchange();
    final settings = _Settings();
    final exchangeBloc = _ExchangeBloc();
    when(() => settings.state).thenReturn(_settingsState(Environment.mainnet));
    when(() => exchangeBloc.state)
        .thenReturn(const ExchangeLoading(_testSession));
    ExchangeAccess current = const ExchangeAccessSignedIn(_testSession);
    when(() => lifecycle.current).thenAnswer((_) => current);
    when(lifecycle.watch).thenAnswer((_) => const Stream.empty());
    when(lifecycle.signOut).thenAnswer((_) async {
      current = const ExchangeAccessDisabled();
      return const Ok(null);
    });
    final exchange = exchangeForTesting(access: lifecycle);
    final router = GoRouter(
      initialLocation: WalletRoute.walletHome.path,
      routes: [
        GoRoute(
          path: WalletRoute.walletHome.path,
          name: WalletRoute.walletHome.name,
          builder: (_, _) => const Scaffold(body: Text('Wallet destination')),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SizedBox.shrink(),
          routes: _mountSettings(exchange),
        ),
        GoRoute(
          path: PayRoute.pay.path,
          name: PayRoute.pay.name,
          builder: (_, _) => const Scaffold(body: Text('Pay destination')),
        ),
        GoRoute(
          path: TransactionsRoute.exchangeTransactions.path,
          name: TransactionsRoute.exchangeTransactions.name,
          builder: (_, _) =>
              const Scaffold(body: Text('Exchange history destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(settings.close);
    addTearDown(exchangeBloc.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settings),
          BlocProvider<ExchangeBloc>.value(value: exchangeBloc),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.pushNamed<void>(ExchangeSettingsRoute.home.name);
    await tester.pumpAndSettle();
    final loc = ExchangeLocalizations.of(
      tester.element(find.byType(ExchangeSettingsScreen)),
    );
    for (final (label, destination) in [
      (loc.exchangeSettingsRecipientsTitle, 'Pay destination'),
      (loc.exchangeSettingsTransactionsTitle, 'Exchange history destination'),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(destination), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ExchangeSettingsScreen), findsOneWidget);
    }
    router.pop();
    router.pushNamed<void>(ExchangeAccessSettingsNavigation.name);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BullSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.exchangeAccessDisableConfirm));
    await tester.pumpAndSettle();
    verify(lifecycle.signOut).called(1);
    expect(find.text('Wallet destination'), findsOneWidget);
    expect(router.canPop(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
