import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/public/recoverbull_feature.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _pumpRouter(WidgetTester tester, RecoverBullFlow flow) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TextButton(
          onPressed: () => RecoverBullFeature.open<void>(context, flow),
          child: const Text('Open'),
        ),
      ),
      GoRoute(
        path: '/vault',
        name: 'recoverbullFlows',
        builder: (context, state) {
          final request = state.extra! as RecoverBullFlowRequest;
          return Text(request.flow.name);
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: RecoverBullFeature.localizationsDelegates,
      supportedLocales: RecoverBullLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  return router;
}

void main() {
  for (final flow in RecoverBullFlow.values) {
    testWidgets('opens ${flow.name} without a shell locator', (tester) async {
      await _pumpRouter(tester, flow);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      if (flow == RecoverBullFlow.viewVaultKey) {
        expect(find.text('Security Warning'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }
      expect(find.text(flow.name), findsOneWidget);
    });
  }

  testWidgets('declining the vault key warning opens nothing', (tester) async {
    await _pumpRouter(tester, RecoverBullFlow.viewVaultKey);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text(RecoverBullFlow.viewVaultKey.name), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
