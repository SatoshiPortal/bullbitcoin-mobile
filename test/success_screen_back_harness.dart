import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Pushes [screen] over a flow page above the route named [homeName], presses
/// system back, and expects to land where the screen's close action leads.
Future<void> expectSystemBackClosesTo(
  WidgetTester tester, {
  required String homeName,
  required String homePath,
  required Widget screen,
}) async {
  final router = GoRouter(
    initialLocation: homePath,
    routes: [
      GoRoute(
        name: homeName,
        path: homePath,
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/flow',
        builder: (context, state) => const Scaffold(body: Text('flow')),
      ),
      GoRoute(path: '/success', builder: (context, state) => screen),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  router.push('/flow');
  await tester.pumpAndSettle();
  router.push('/success');
  await tester.pumpAndSettle();

  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();

  expect(find.text('flow'), findsNothing);
  expect(find.text('home'), findsOneWidget);
}
