import 'package:bull_exchange/bull_exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/testing.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeFacade {}

class _Settings extends MockCubit<SettingsState> implements SettingsCubit {}

class _ExchangeCubit extends MockCubit<ExchangeState>
    implements ExchangeCubit {}

class _ExchangeState extends Mock implements ExchangeState {}

void main() {
  testWidgets('sign-in from manage access returns to the same route', (
    tester,
  ) async {
    final exchange = _Exchange();
    final settings = _Settings();
    when(
      () => exchange.currentAccess,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedOut));
    when(exchange.watchAccess).thenAnswer((_) => const Stream.empty());
    when(() => settings.state).thenReturn(const SettingsState());
    locator.registerSingleton<ExchangeFacade>(exchange);
    addTearDown(() => locator.unregister<ExchangeFacade>());
    final manage =
        BullExchangeFeature.mount(
          settings: SettingsRouter.exchangeSettingsHost,
          networkUnavailable: () async => false,
          showWebsiteOnly: (_) => false,
          unavailableRedirectPath: '/home',
          brandAssetPath: 'unused',
          copy: (_) => fail('unexpected landing route'),
          onSignIn: (_) {},
          onExit: (_) {},
        ).settingsRoutes.whereType<GoRoute>().singleWhere(
          (route) => route.name == ExchangeAccessSettingsNavigation.name,
        );
    final router = GoRouter(
      initialLocation: '/manage',
      routes: [
        GoRoute(path: '/manage', builder: manage.builder),
        GoRoute(
          path: '/auth',
          name: ExchangeRoute.exchangeAuth.name,
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
    final exchangeCubit = _ExchangeCubit();
    final exchangeState = _ExchangeState();
    when(() => exchangeState.notLoggedIn).thenReturn(false);
    when(() => exchangeState.hasUser).thenReturn(true);
    when(() => exchangeCubit.state).thenReturn(exchangeState);
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
    when(
      () => exchange.currentAccess,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    when(exchange.watchAccess).thenAnswer((_) => const Stream.empty());
    locator.registerSingleton<ExchangeFacade>(exchange);
    addTearDown(() => locator.unregister<ExchangeFacade>());
    final settingsRoutes = SettingsRouter.childRoutes(
      accessRoutes: const [],
      addressRoutes: const [],
      exchangeSettingsRoutes: BullExchangeFeature.mount(
        settings: SettingsRouter.exchangeSettingsHost,
        networkUnavailable: () async => false,
        showWebsiteOnly: (_) => false,
        unavailableRedirectPath: '/home',
        brandAssetPath: 'unused',
        copy: (_) => fail('unexpected landing route'),
        onSignIn: (_) {},
        onExit: (_) {},
      ).settingsRoutes,
      appSettingsRoutes: const [],
      onBackupTestSucceeded: (_) {},
      priceRoutes: const [],
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
          name: ExchangeRoute.exchangeHome.name,
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
          BlocProvider<ExchangeCubit>.value(value: exchangeCubit),
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
    when(() => exchange.currentAccess)
        .thenReturn(const ExchangeAccessDisabled());
    var listens = 0;
    var cancels = 0;
    final changes = StreamController<ExchangeAccess>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    when(exchange.watchAccess).thenAnswer((_) => changes.stream);
    locator.registerSingleton<ExchangeFacade>(exchange);
    addTearDown(() => locator.unregister<ExchangeFacade>());
    final route =
        BullExchangeFeature.mount(
          settings: SettingsRouter.exchangeSettingsHost,
          networkUnavailable: () async => false,
          showWebsiteOnly: (_) => false,
          unavailableRedirectPath: '/home',
          brandAssetPath: 'unused',
          copy: (_) => fail('unexpected landing route'),
          onSignIn: (_) {},
          onExit: (_) {},
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
}
