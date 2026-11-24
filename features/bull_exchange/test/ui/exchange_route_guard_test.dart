import 'package:bull_exchange/bull_exchange.dart'
    show ExchangeLocalizations, ExchangeSettingsRoute;
import 'package:bull_exchange/testing.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

abstract interface class _Access {
  Future<Result<ExchangeAvailability, ExchangeFailure>> guardTradingEntry();
  Future<Result<void, ExchangeFailure>> resolveAccess();
}

class _Exchange extends Mock implements _Access {}

const _accountPaths = [
  '/buy',
  '/buy/details',
  '/sell',
  '/sell/details',
  '/pay',
  '/pay/details',
  '/withdraw',
  '/withdraw/confirmation',
  '/fund-exchange',
  '/fund-exchange/cop-bank-transfer-input',
  '/dca',
  '/auto-buy',
  '/limit-orders/create',
  '/limit-orders/abc',
  '/exchange/kyc',
  '/settings/exchange-security',
  '/settings/exchange-referrals',
  '/settings/exchange-account-info',
  '/settings/exchange-app-settings',
  '/settings/secure-file-upload',
  '/settings/exchange-statistics',
  '/settings/exchange-bitcoin-wallets',
];

const _openPaths = [
  '/exchange',
  '/exchange/landing',
  '/exchange/auth',
  '/exchange/support-chat',
  '/settings/exchange-settings',
  '/settings/exchange-access',
];

final _paths =
    ExchangeGuardedPaths.mounted +
    ExchangeGuardedPaths.settingsUnder('/settings');

const _outsidePaths = [
  '/home',
  '/settings',
  '/settings/wallet-settings',
  '/buyer',
  '/payjoin',
  '/fund',
  '/exchanges',
];

Future<GoRouter> _pumpRouter(
  WidgetTester tester,
  _Exchange exchange,
  String target,
) async {
  final key = GlobalKey<NavigatorState>();
  final guard = ExchangeRouteGuard(
    navigatorKey: key,
    checkAvailability: exchange.guardTradingEntry,
    resolveAccess: exchange.resolveAccess,
    paths: _paths,
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
        path: target,
        builder: (_, _) => const Scaffold(body: Text('Target')),
      ),
      GoRoute(
        path: '/exchange/landing',
        builder: (_, _) => const Scaffold(body: Text('Website only')),
      ),
      GoRoute(
        path: '/exchange/auth',
        builder: (context, state) => Scaffold(
          body: TextButton(
            // Stands in for the auth route's Done exit.
            onPressed: () =>
                context.pushReplacement(state.uri.queryParameters['resume']!),
            child: const Text('Sign in'),
          ),
        ),
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
  return router;
}

void main() {
  group('ExchangeGuardedPaths', () {
    for (final path in _accountPaths) {
      test('$path needs the account', () {
        expect(_paths.needOf(path), ExchangeRouteNeed.account);
      });
    }
    for (final path in _openPaths) {
      test('$path is open', () {
        expect(_paths.needOf(path), ExchangeRouteNeed.open);
      });
    }
    for (final path in _outsidePaths) {
      test('$path is not an exchange route', () {
        expect(_paths.needOf(path), isNull);
      });
    }

    test('the mounted routes name no host path', () {
      for (final path in [
        ...ExchangeGuardedPaths.mounted.accountRoots,
        ...ExchangeGuardedPaths.mounted.openPaths,
      ]) {
        expect(path, isNot(startsWith('/settings')));
      }
      for (final path in _accountPaths.where(
        (p) => p.startsWith('/settings'),
      )) {
        expect(ExchangeGuardedPaths.mounted.needOf(path), isNull);
      }
    });

    test('the settings routes follow the host mount point', () {
      final paths = ExchangeGuardedPaths.settingsUnder('/preferences/');
      expect(
        paths.needOf('/preferences/exchange-security'),
        ExchangeRouteNeed.account,
      );
      expect(
        paths.needOf('/preferences/exchange-bitcoin-wallets'),
        ExchangeRouteNeed.account,
      );
      expect(
        paths.needOf('/preferences/exchange-settings'),
        ExchangeRouteNeed.open,
      );
      expect(
        paths.needOf('/preferences/exchange-access'),
        ExchangeRouteNeed.open,
      );
      expect(paths.needOf('/settings/exchange-security'), isNull);
    });

    test('every exchange settings route has a need', () {
      expect(
        {
          for (final route in ExchangeSettingsRoute.values)
            route: exchangeSettingsRouteNeed(route),
        },
        {
          ExchangeSettingsRoute.home: ExchangeRouteNeed.open,
          ExchangeSettingsRoute.security: ExchangeRouteNeed.account,
          ExchangeSettingsRoute.referrals: ExchangeRouteNeed.account,
          ExchangeSettingsRoute.accountInfo: ExchangeRouteNeed.account,
          ExchangeSettingsRoute.preferences: ExchangeRouteNeed.account,
          ExchangeSettingsRoute.secureFileUpload: ExchangeRouteNeed.account,
          ExchangeSettingsRoute.statistics: ExchangeRouteNeed.account,
        },
      );
    });

    test('a host route added to the composition is covered', () {
      final paths =
          _paths + const ExchangeGuardedPaths(accountRoots: ['/host-trade']);
      expect(paths.needOf('/host-trade/x'), ExchangeRouteNeed.account);
    });
  });

  group('decideExchangeRoute: every need x every availability', () {
    final expected = <(ExchangeRouteNeed, ExchangeAvailability), Type>{
      (ExchangeRouteNeed.open, ExchangeAvailability.ready):
          ExchangeRouteAllowed,
      (ExchangeRouteNeed.open, ExchangeAvailability.signInRequired):
          ExchangeRouteAllowed,
      (ExchangeRouteNeed.open, ExchangeAvailability.unavailable):
          ExchangeRouteAllowed,
      (ExchangeRouteNeed.open, ExchangeAvailability.hidden):
          ExchangeRouteAllowed,
      (ExchangeRouteNeed.open, ExchangeAvailability.websiteOnly):
          ExchangeRouteAllowed,
      (ExchangeRouteNeed.account, ExchangeAvailability.ready):
          ExchangeRouteAllowed,
      (ExchangeRouteNeed.account, ExchangeAvailability.signInRequired):
          ExchangeRouteSignIn,
      (ExchangeRouteNeed.account, ExchangeAvailability.unavailable):
          ExchangeRouteUnavailable,
      (ExchangeRouteNeed.account, ExchangeAvailability.hidden):
          ExchangeRouteUnavailable,
      (ExchangeRouteNeed.account, ExchangeAvailability.websiteOnly):
          ExchangeRouteWebsiteOnly,
    };

    test('the table names every pair', () {
      expect(
        expected.length,
        ExchangeRouteNeed.values.length * ExchangeAvailability.values.length,
      );
    });

    for (final MapEntry(key: (need, availability), value: decision)
        in expected.entries) {
      test('${need.name} x ${availability.name} -> $decision', () {
        expect(decideExchangeRoute(need, availability).runtimeType, decision);
      });
    }

    for (final path in _accountPaths) {
      for (final availability in ExchangeAvailability.values) {
        test('$path x ${availability.name}', () {
          expect(
            decideExchangeRoute(_paths.needOf(path)!, availability).runtimeType,
            expected[(ExchangeRouteNeed.account, availability)],
          );
        });
      }
    }
    for (final path in _openPaths) {
      for (final availability in ExchangeAvailability.values) {
        test('$path x ${availability.name}', () {
          expect(
            decideExchangeRoute(_paths.needOf(path)!, availability).runtimeType,
            ExchangeRouteAllowed,
          );
        });
      }
    }
  });

  test('the sign-in location carries the full requested location', () {
    final location = Uri.parse('/limit-orders/abc?from=home');
    final signIn = Uri.parse(exchangeSignInResuming(location));
    expect(signIn.path, '/exchange/auth');
    expect(signIn.queryParameters['resume'], '/limit-orders/abc?from=home');
  });

  for (final path in ['/buy', '/withdraw', '/fund-exchange', '/dca']) {
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
      final router = await _pumpRouter(tester, exchange, path);
      router.push(path);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/home');
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trading is unavailable.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      verify(exchange.resolveAccess).called(1);
      expect(find.text('Target'), findsOneWidget);
      BullSnackBar.dismiss();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('signed out, $path signs in and then resumes it (INT-13)', (
      tester,
    ) async {
      final exchange = _Exchange();
      var signedIn = false;
      when(exchange.guardTradingEntry).thenAnswer(
        (_) async => Ok(
          signedIn
              ? ExchangeAvailability.ready
              : ExchangeAvailability.signInRequired,
        ),
      );
      final router = await _pumpRouter(tester, exchange, path);
      router.push(path);
      await tester.pumpAndSettle();
      final signIn = router.state.uri;
      expect(signIn.path, '/exchange/auth');
      expect(signIn.queryParameters['resume'], path);
      expect(find.text('Target'), findsNothing);

      signedIn = true;
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, path);
      expect(find.text('Target'), findsOneWidget);
    });
  }

  for (final path in ['/buy', '/sell', '/settings/exchange-account-info']) {
    testWidgets('iOS without superuser: $path opens the website-only landing', (
      tester,
    ) async {
      final exchange = _Exchange();
      when(exchange.guardTradingEntry)
          .thenAnswer((_) async => const Ok(ExchangeAvailability.websiteOnly));
      final router = await _pumpRouter(tester, exchange, path);
      router.push(path);
      await tester.pumpAndSettle();
      expect(
        router.state.uri.path,
        '/exchange/landing',
      );
      expect(find.text('Website only'), findsOneWidget);
      expect(find.text('Target'), findsNothing);
      expect(find.text('Trading is unavailable.'), findsNothing);
    });
  }

  testWidgets('a signed-out withdrawal never builds the withdrawal (B5)', (
    tester,
  ) async {
    final exchange = _Exchange();
    when(exchange.guardTradingEntry)
        .thenAnswer((_) async => const Ok(ExchangeAvailability.signInRequired));
    final router = await _pumpRouter(tester, exchange, '/withdraw');
    router.push('/withdraw');
    await tester.pumpAndSettle();
    expect(find.text('Target'), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('open routes never ask for the access state', (tester) async {
    final exchange = _Exchange();
    final router = await _pumpRouter(
      tester,
      exchange,
      '/settings/exchange-settings',
    );
    router.push('/settings/exchange-settings');
    await tester.pumpAndSettle();
    expect(find.text('Target'), findsOneWidget);
    verifyNever(exchange.guardTradingEntry);
  });
}
