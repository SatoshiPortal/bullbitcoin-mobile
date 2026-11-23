import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/testing.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeFacade {}

class _ExchangeCubit extends MockCubit<ExchangeState>
    implements ExchangeCubit {}

ExchangeRouterConfig _config({
  required Future<bool> Function() unavailable,
  void Function(BuildContext)? onExit,
}) => ExchangeRouterConfig(
  networkUnavailable: unavailable,
  isSuperuser: (_) => false,
  homePath: '/home',
  buildHomeCards: () => [],
  onHomeRefresh: () {},
  onExit: onExit ?? (_) {},
  onOpenSettings: (_) {},
  onAction: (_, _) {},
);

void main() {
  testWidgets(
    'injected network refusal redirects before exchange presentation',
    (tester) async {
      var checks = 0;
      final router = GoRouter(
        initialLocation: BullExchangeNavigation.landingPath,
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const Text('home')),
          ...ExchangeRouter.routes(
            _config(
              unavailable: () async {
                checks++;
                return true;
              },
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(checks, 1);
    },
  );

  Future<
    ({
      StreamController<ExchangeAccess> changes,
      void Function(ExchangeAccess) set,
    })
  >
  pumpTrade(WidgetTester tester, {void Function(BuildContext)? onExit}) async {
    final exchange = _Exchange();
    final changes = StreamController<ExchangeAccess>.broadcast();
    ExchangeAccess current = const ExchangeAccessEnabled(
      ExchangeAccessSession.signedIn,
    );
    when(() => exchange.currentAccess).thenAnswer((_) => current);
    when(exchange.watchAccess).thenAnswer((_) => changes.stream);
    locator.registerSingleton<ExchangeFacade>(exchange);
    addTearDown(() => locator.unregister<ExchangeFacade>());
    final cubit = _ExchangeCubit();
    when(() => cubit.state).thenReturn(const ExchangeState());
    final router = GoRouter(
      initialLocation: ExchangeRoute.exchangeHome.path,
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        ...ExchangeRouter.routes(
          _config(unavailable: () async => false, onExit: onExit),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(cubit.close);
    addTearDown(changes.close);
    await tester.pumpWidget(
      BlocProvider<ExchangeCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
    const signedIn = ExchangeAccessEnabled(ExchangeAccessSession.signedIn);
    const signedOut = ExchangeAccessEnabled(ExchangeAccessSession.signedOut);
    final exchange = _Exchange();
    final changes = StreamController<ExchangeAccess>.broadcast();
    ExchangeAccess current = signedIn;
    when(() => exchange.currentAccess).thenAnswer((_) => current);
    when(exchange.watchAccess).thenAnswer((_) => changes.stream);
    locator.registerSingleton<ExchangeFacade>(exchange);
    addTearDown(() => locator.unregister<ExchangeFacade>());
    final cubit = _ExchangeCubit();
    // The cubit resets to its empty state when the session ends.
    when(() => cubit.state).thenReturn(const ExchangeState());
    final router = GoRouter(
      initialLocation: ExchangeRoute.exchangeHome.path,
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        ...ExchangeRouter.routes(_config(unavailable: () async => false)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<ExchangeCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
