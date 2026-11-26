import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/support_chat/ui/exchange_support_chat_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullUiLocalizations;
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support_chat_usecase_fakes.dart';

void main() {
  late int exits;

  // Logged out, so the chat capability is not opened.
  GoRouter router({required String initialLocation}) {
    exits = 0;
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        ExchangeSupportChatRouter.route(
          exchange: () => fail('unexpected Exchange lookup'),
          pickImages: FakePickImageAttachmentsUsecase(
            () => fail('unexpected image pick'),
          ),
          isLoggedIn: (_) => false,
          enableLogin: (_) async => fail('unexpected activation'),
          onLogin: (_, _) => fail('unexpected authentication'),
          loginLabel: (_) => 'Sign in',
          failureMessage: (_, _) => fail('unexpected failure'),
          onExit: (_, _) => exits++,
          onMessagesRead: (_) => fail('unexpected read receipt'),
        ),
      ],
    );
  }

  Widget app(GoRouter router) => MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(extensions: testBullExtensions),
    locale: const Locale('en'),
    localizationsDelegates: const [
      BullUiLocalizations.delegate,
      ...ExchangeLocalizations.localizationsDelegates,
    ],
    supportedLocales: ExchangeLocalizations.supportedLocales,
  );

  group('ExchangeSupportChatRouter system back', () {
    testWidgets('exits to the app home when the chat is the only page', (
      tester,
    ) async {
      final r = router(initialLocation: '/exchange/support-chat');
      addTearDown(r.dispose);
      await tester.pumpWidget(app(r));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(exits, 1);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('pops back to the opener when the chat was pushed', (
      tester,
    ) async {
      final r = router(initialLocation: '/home');
      addTearDown(r.dispose);
      await tester.pumpWidget(app(r));
      r.pushNamed(ExchangeSupportChatNavigation.routeName);
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(exits, 0);
      expect(find.text('home'), findsOneWidget);
    });
  });
}
