import '../support/ui_labels.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_navigation_port.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/testing.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/ui/screens/test_completed_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Got it returns to the wallet', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TestCompletedPage()),
        GoRoute(
          path: '/wallet',
          builder: (_, _) => const Scaffold(body: Text('Wallet home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: const [testBullTheme]),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) =>
            RepositoryProvider<RecoverBullNavigationPort>.value(
              value: RecoverBullNavigationCallbacks(
                onOpenTorSettings: () {},
                onOpenWalletHome: () => router.go('/wallet'),
              ),
              child: withTestUiLabels(context, child!),
            ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet home'), findsOneWidget);
  });
}
