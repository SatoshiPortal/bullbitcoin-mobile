import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:receive/setup.dart' show ReceiveLocalizations;
import 'package:receive/src/ui/widgets/receive_network_selection.dart';

/// Drives the real receive tab control inside a router shaped like the app's:
/// the hub is pushed under the receive shell, and the three receive pages are
/// siblings of that shell.
Future<GoRouter> pumpReceive(WidgetTester tester) async {
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/wallet',
    routes: [
      GoRoute(
        name: 'walletHome',
        path: '/wallet',
        builder: (context, _) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            router.goNamed('walletHome');
          },
          child: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.pushNamed('receiveBitcoin'),
                child: const Text('open receive'),
              ),
            ),
          ),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => Scaffold(
          body: Column(
            children: [
              ReceiveNetworkSelection(network: BitcoinNetwork.regtest),
              Expanded(child: child),
            ],
          ),
        ),
        routes: [
          GoRoute(
            name: 'receiveBitcoin',
            path: '/receive/bitcoin',
            builder: (_, _) => const Text('bitcoin page'),
          ),
          GoRoute(
            name: 'receiveLightning',
            path: '/receive/lightning',
            builder: (_, _) => const Text('lightning page'),
          ),
          GoRoute(
            name: 'receiveLiquid',
            path: '/receive/liquid',
            builder: (_, _) => const Text('liquid page'),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.themeData(AppThemeType.dark),
      localizationsDelegates: const [
        bullUiLocalizationsDelegate,
        ReceiveLocalizations.delegate,
      ],
      supportedLocales: ReceiveLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.tap(find.text('open receive'));
  await tester.pumpAndSettle();
  expect(find.text('bitcoin page'), findsOneWidget);
  return router;
}

/// One system back must stay inside the app. When the route under the receive
/// page was dropped the navigator cannot pop and the binding falls through to
/// `SystemNavigator.pop`, which finishes the task.
Future<void> expectSystemBackReturnsHome(
  WidgetTester tester,
  GoRouter router,
) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();

  expect(handled, isTrue, reason: 'system back must not leave the app');
  expect(router.routerDelegate.currentConfiguration.uri.toString(), '/wallet');
  expect(find.text('open receive'), findsOneWidget);
}

void main() {
  testWidgets('system back from an unswitched receive page returns home', (
    tester,
  ) async {
    final router = await pumpReceive(tester);

    await expectSystemBackReturnsHome(tester, router);
  });

  testWidgets('system back after switching receive tabs returns home', (
    tester,
  ) async {
    final router = await pumpReceive(tester);

    await tester.tap(find.text('Lightning'));
    await tester.pumpAndSettle();
    expect(find.text('lightning page'), findsOneWidget);

    await tester.tap(find.text('Liquid'));
    await tester.pumpAndSettle();
    expect(find.text('liquid page'), findsOneWidget);

    await tester.tap(find.text('Bitcoin'));
    await tester.pumpAndSettle();
    expect(find.text('bitcoin page'), findsOneWidget);

    expect(
      router.canPop(),
      isTrue,
      reason: 'the hub must stay under the receive page across a tab switch',
    );

    await expectSystemBackReturnsHome(tester, router);
  });
}
