import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeFacade {}

void main() {
  for (final path in [
    '/buy',
    '/sell',
    '/pay',
    '/buy/details',
    '/sell/details',
    '/pay/details',
  ]) {
    testWidgets('$path stays on Home until access can be retried', (
      tester,
    ) async {
      final exchange = _Exchange();
      var available = false;
      when(exchange.guardTradingEntry).thenAnswer(
        (_) async => Ok(
          available
              ? ExchangeAvailability.ready
              : ExchangeAvailability.unavailable,
        ),
      );
      when(exchange.resolveAccess).thenAnswer((_) async {
        available = true;
        return const Ok(null);
      });
      final key = GlobalKey<NavigatorState>();
      final guard = ExchangeTradingGuard(exchange, key);
      late final GoRouter router;
      router = GoRouter(
        navigatorKey: key,
        initialLocation: '/home',
        onEnter: (context, current, next, routing) =>
            guard.onEnter(context, current, next, router),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: path,
            builder: (_, _) => const Scaffold(body: Text('Trade target')),
          ),
          GoRoute(
            path: '/exchange/auth',
            builder: (_, _) => const Scaffold(body: Text('Sign in')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      router.push(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trading is unavailable.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      verify(exchange.resolveAccess).called(1);
      expect(find.text('Trade target'), findsOneWidget);
      BullSnackBar.dismiss();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
