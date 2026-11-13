import 'package:bb_mobile/features/settings/ui/screens/exchange/exchange_settings_screen.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/domain/usecases/manage_exchange_access_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/exchange_access_settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/exchange_access_settings_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeFacade {}

class _Set extends Mock implements SetSettingsExchangeAccessUsecase {}

class _Settings extends MockCubit<SettingsState> implements SettingsCubit {}

class _ExchangeCubit extends MockCubit<ExchangeState>
    implements ExchangeCubit {}

class _ExchangeState extends Mock implements ExchangeState {}

void main() {
  for (final signedIn in [true, false]) {
    testWidgets(
      signedIn
          ? 'signed-in account opens account settings'
          : 'sign-in returns to manage access',
      (tester) async {
        final exchange = _Exchange();
        final set = _Set();
        final settings = _Settings();
        final changes = StreamController<ExchangeAccess>.broadcast();
        final access = ExchangeAccessEnabled(
          signedIn
              ? ExchangeAccessSession.signedIn
              : ExchangeAccessSession.signedOut,
        );
        when(() => exchange.currentAccess).thenReturn(access);
        when(exchange.watchAccess).thenAnswer((_) => changes.stream);
        when(() => settings.state).thenReturn(const SettingsState());
        final cubit = ExchangeAccessSettingsCubit(
          WatchSettingsExchangeAccessUsecase(exchange),
          set,
        );
        final router = GoRouter(
          initialLocation: '/manage',
          routes: [
            GoRoute(
              path: '/manage',
              builder: (context, state) => ExchangeAccessSettingsScreen(
                cubit: cubit,
                onBack: () {},
                onAuthenticate: () => context.push<void>('/auth'),
                onOpenAccount: () => context.push('/account'),
                onDisabled: () {},
                onAuthenticated: () {},
              ),
            ),
            GoRoute(
              path: '/account',
              builder: (_, _) => const Scaffold(body: Text('Account settings')),
            ),
            GoRoute(
              path: '/auth',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Return'),
                ),
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(
          find.byType(ExchangeAccessSettingsScreen),
        );
        final labels = AppLocalizations.of(context);
        await tester.tap(
          find.text(
            signedIn
                ? labels.settingsAccountSettingsTitle
                : labels.exchangeAccessSignIn,
          ),
        );
        await tester.pumpAndSettle();
        if (signedIn) {
          expect(find.text('Account settings'), findsOneWidget);
        } else {
          expect(find.text('Return'), findsOneWidget);
          await tester.tap(find.text('Return'));
          await tester.pumpAndSettle();
          expect(find.byType(ExchangeAccessSettingsScreen), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        await changes.close();
        await settings.close();
      },
    );
  }
  testWidgets('real manage route reaches account settings and security route', (
    tester,
  ) async {
    final exchange = _Exchange();
    final set = _Set();
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
    locator.registerFactory<ExchangeAccessSettingsCubit>(
      () => ExchangeAccessSettingsCubit(
        WatchSettingsExchangeAccessUsecase(exchange),
        set,
      ),
    );
    locator.registerSingleton<ExchangeFacade>(exchange);
    addTearDown(() => locator.unregister<ExchangeFacade>());
    final settingsRoute = SettingsRouter.route(
      buildPriceHistory: (_) => const SizedBox.shrink(),
    );
    final manage = settingsRoute.routes.whereType<GoRoute>().singleWhere(
      (route) => route.name == SettingsRoute.exchangeAccess.name,
    );
    final account = settingsRoute.routes.whereType<GoRoute>().singleWhere(
      (route) => route.name == SettingsRoute.exchangeSettings.name,
    );
    final router = GoRouter(
      initialLocation: '/manage',
      routes: [
        GoRoute(
          path: '/manage',
          name: SettingsRoute.exchangeAccess.name,
          builder: manage.builder,
        ),
        GoRoute(
          path: '/account',
          name: SettingsRoute.exchangeSettings.name,
          builder: account.builder,
        ),
        GoRoute(
          path: '/exchange',
          name: ExchangeRoute.exchangeHome.name,
          builder: (_, _) => const Scaffold(body: Text('Exchange dashboard')),
        ),
        GoRoute(
          path: '/security',
          name: SettingsRoute.exchangeSecurity.name,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    var context = tester.element(find.byType(ExchangeAccessSettingsScreen));
    await tester.tap(
      find.text(AppLocalizations.of(context).settingsAccountSettingsTitle),
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
    await locator.unregister<ExchangeAccessSettingsCubit>();
    await settings.close();
    await exchangeCubit.close();
  });
}
