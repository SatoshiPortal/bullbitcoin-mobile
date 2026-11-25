import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';

import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/testing.dart';
import 'package:bb_mobile/generated/novlang/novlang_bull_exchange_localizations.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:preferences/preferences.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:novlang/novlang.dart';

const _testSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'test',
);

class _Access extends Mock implements ExchangeAccessLifecycle {}

class _Preferences extends Mock implements Preferences {}

class _ExchangeBloc extends MockBloc<ExchangeEvent, ExchangeState>
    implements ExchangeBloc {}

class _UnreadBloc extends MockBloc<SupportUnreadEvent, SupportUnreadState>
    implements SupportUnreadBloc {}

/// The blocs ExchangeSessionScope provides above the exchange routes.
Widget _scoped(_ExchangeBloc exchange, Widget child) {
  final unread = _UnreadBloc();
  when(() => unread.state).thenReturn(const UnreadSignedOut());
  return MultiBlocProvider(
    providers: [
      BlocProvider<ExchangeBloc>.value(value: exchange),
      BlocProvider<SupportUnreadBloc>.value(value: unread),
    ],
    child: child,
  );
}

BullExchangeFeature _mount({
  required Exchange Function() exchange,
  void Function(BuildContext)? onExit,
}) => BullExchangeFeature.mount(
  exchange: exchange,
  preferences: () => throw StateError('Unexpected preferences'),
  isSuperuser: (_) => false,
  homePath: '/home',
  onExit: onExit ?? (_) {},
  onOpenSettings: (_) {},
  onAction: (_, _) {},
  brandAssetPath: Assets.logos.bbLogoSmall.path,
  settingsAssetPath: Assets.icons.settingsLine.path,
);

List<RouteBase> _routes(BullExchangeFeature feature) => [
  ?feature.dashboardRoute,
  ...feature.routes,
];

void main() {
  test('landing copy retains the App Store vocabulary override', () async {
    final apple = await const NovlangExchangeLocalizationsDelegate(
      NovlangPolicy.apple,
    ).load(const Locale('en'));
    final unrestricted = await const NovlangExchangeLocalizationsDelegate(
      NovlangPolicy.none,
    ).load(const Locale('en'));

    expect(
      apple.exchangeLandingConnectAccount,
      'Connect your Bull Bitcoin account',
    );
    expect(
      unrestricted.exchangeLandingConnectAccount,
      'Connect your Bull Bitcoin exchange account',
    );
    expect(
      apple.exchangeLandingDisclaimerLegal,
      unrestricted.exchangeLandingDisclaimerLegal,
    );
  });

  testWidgets('support login preserves the authentication source and draft', (
    tester,
  ) async {
    final lifecycle = _Access();
    when(() => lifecycle.current)
        .thenReturn(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    when(() => lifecycle.enable(forSupport: true))
        .thenAnswer((_) async => const Ok(null));
    final capability = exchangeForTesting(access: lifecycle);
    final feature = _mount(exchange: () => capability);
    GoRouterState? authentication;
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
        ?feature.supportChatRoute,
        GoRoute(
          path: '/auth',
          name: BullExchangeNavigation.authName,
          builder: (_, state) {
            authentication = state;
            return const Scaffold(body: Text('Authentication'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        locale: const Locale('en'),
        localizationsDelegates: const [
          ExchangeLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    const draft = ExchangeSupportChatDraft(initialMessage: 'Help');
    router.pushNamed(ExchangeSupportChatNavigation.routeName, extra: draft);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).last);
    await tester.tap(
      find.text(AppLocalizations.of(context).exchangeLoginButton),
    );
    await tester.pumpAndSettle();

    verify(() => lifecycle.enable(forSupport: true)).called(1);
    expect(authentication?.extra, same(draft));
    expect(authentication?.uri.queryParameters['from'], 'support');
  });

  testWidgets(
    'injected network refusal redirects before exchange presentation',
    (tester) async {
      final preferences = _Preferences();
      when(preferences.readActiveEnvironment)
          .thenAnswer((_) async => const Ok(Environment.regtest));
      final capability = exchangeForTesting(
        sessionPreferences: preferences,
        basicAuth: ExchangeCredentials.openBasicAuth(
          InMemoryExchangeCredentialStorage(),
        ),
      );
      final router = GoRouter(
        initialLocation: BullExchangeNavigation.landingPath,
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const Text('home')),
          ..._routes(_mount(exchange: () => capability)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      verify(preferences.readActiveEnvironment).called(1);
    },
  );

  Future<
    ({
      StreamController<ExchangeAccess> changes,
      void Function(ExchangeAccess) set,
    })
  >
  pumpTrade(WidgetTester tester, {void Function(BuildContext)? onExit}) async {
    final exchange = _Access();
    final changes = StreamController<ExchangeAccess>.broadcast();
    ExchangeAccess current = const ExchangeAccessSignedIn(_testSession);
    when(() => exchange.current).thenAnswer((_) => current);
    when(exchange.watch).thenAnswer((_) => changes.stream);
    final capability = exchangeForTesting(access: exchange);
    final cubit = _ExchangeBloc();
    when(() => cubit.state).thenReturn(const ExchangeSignedOut());
    final router = GoRouter(
      initialLocation: BullExchangeNavigation.dashboardPath,
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        ..._routes(_mount(exchange: () => capability, onExit: onExit)),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(cubit.close);
    addTearDown(changes.close);
    await tester.pumpWidget(
      _scoped(
        cubit,
        MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ExchangeLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return (
      changes: changes,
      set: (ExchangeAccess access) {
        current = access;
        changes.add(access);
      },
    );
  }

  testWidgets(
    'an open Trade screen returns home when sign-out turns exchange off',
    (tester) async {
      var exits = 0;
      final trade = await pumpTrade(
        tester,
        onExit: (context) {
          exits++;
          context.go('/home');
        },
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Explicit sign-out reports an incomplete cleanup, then disabled access.
      trade.set(const ExchangeAccessSignOutIncomplete());
      await tester.pump();
      await tester.pump();
      trade.set(const ExchangeAccessDisabled());
      await tester.pump();
      await tester.pump();

      expect(find.byType(ExchangeLandingScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(exits, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('an open Trade screen leaves for sign-in when the session ends', (
    tester,
  ) async {
    const signedIn = ExchangeAccessSignedIn(_testSession);
    const signedOut = ExchangeAccessSignedOut(ExchangeEnvironment.mainnet);
    final exchange = _Access();
    final changes = StreamController<ExchangeAccess>.broadcast();
    ExchangeAccess current = signedIn;
    when(() => exchange.current).thenAnswer((_) => current);
    when(exchange.watch).thenAnswer((_) => changes.stream);
    final capability = exchangeForTesting(access: exchange);
    final cubit = _ExchangeBloc();
    // The bloc is signed out once the session ends.
    when(() => cubit.state).thenReturn(const ExchangeSignedOut());
    final router = GoRouter(
      initialLocation: BullExchangeNavigation.dashboardPath,
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        ..._routes(_mount(exchange: () => capability)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _scoped(
        cubit,
        MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ExchangeLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ExchangeLandingScreen), findsNothing);

    current = signedOut;
    changes.add(signedOut);
    await tester.pump();
    await tester.pump();

    expect(find.byType(ExchangeLandingScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await changes.close();
    await cubit.close();
  });
}
