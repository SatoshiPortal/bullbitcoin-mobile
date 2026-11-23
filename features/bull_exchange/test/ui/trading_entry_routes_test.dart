import 'package:bull_ui/app_theme.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

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
      var retries = 0;
      final key = GlobalKey<NavigatorState>();
      final guard = ExchangeTradingGuard(
        navigatorKey: key,
        checkAvailability: () async => Ok(
          retries == 0
              ? ExchangeAvailability.unavailable
              : ExchangeAvailability.ready,
        ),
        resolveAccess: () async {
          retries++;
          return const Ok(null);
        },
      );
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
          localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
          supportedLocales: ExchangeLocalizations.supportedLocales,
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
      expect(retries, 1);
      expect(find.text('Trade target'), findsOneWidget);
      BullSnackBar.dismiss();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
