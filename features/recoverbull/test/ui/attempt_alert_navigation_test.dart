import '../support/ui_labels.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/ui/screens/attempt_alert_detail_page.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('alert details use the shell router and retain the source page', (
    tester,
  ) async {
    final alerts = [
      RecoverBullAttemptAlert(RecoverBullAttemptAlertKind.servicePressure),
    ];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  openRecoverBullAttemptAlertDetails(context, alerts),
              child: const Text('Details'),
            ),
          ),
        ),
        GoRoute(
          path: RecoverBullRoute.recoverbullAttemptAlerts.path,
          name: RecoverBullRoute.recoverbullAttemptAlerts.name,
          builder: (_, state) => RecoverBullAttemptAlertDetailPage(
            sourceAlerts: state.extra! as List<RecoverBullAttemptAlert>,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        builder: (context, child) => withTestUiLabels(context, child!),
        theme: ThemeData(extensions: const [testBullTheme]),
        routerConfig: router,
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    alerts.clear();
    await tester.pumpAndSettle();
    final page = tester.widget<RecoverBullAttemptAlertDetailPage>(
      find.byType(RecoverBullAttemptAlertDetailPage),
    );
    expect(page.sourceAlerts, hasLength(1));
    expect(() => page.sourceAlerts.clear(), throwsUnsupportedError);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
  });
}
