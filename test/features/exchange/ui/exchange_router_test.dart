import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_landing_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeFacade {}

class _ExchangeCubit extends MockCubit<ExchangeState>
    implements ExchangeCubit {}

ExchangeRouterConfig _config({required Future<bool> Function() unavailable}) =>
    ExchangeRouterConfig(
      networkUnavailable: unavailable,
      isSuperuser: (_) => false,
      homePath: '/home',
      buildHomeCards: () => [],
      onHomeRefresh: () {},
      onExit: (_) {},
      onOpenSettings: (_) {},
      onAction: (_, _) {},
    );

void main() {
  testWidgets(
    'injected network refusal redirects before exchange presentation',
    (tester) async {
      var checks = 0;
      final router = GoRouter(
        initialLocation: ExchangeRoute.exchangeLanding.path,
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
