import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late int exits;

  // Logged out, so the route shows the injected login screen: the real chat
  // screen needs the service locator.
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
          isLoggedIn: (_) => false,
          loginScreenBuilder: (_) => const Scaffold(body: Text('support')),
          onExit: (_, _) => exits++,
        ),
      ],
    );
  }

  group('ExchangeSupportChatRouter system back', () {
    testWidgets('exits to the app home when the chat is the only page', (
      tester,
    ) async {
      final r = router(initialLocation: '/exchange/support-chat');
      addTearDown(r.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: r));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(exits, 1);
      expect(find.text('support'), findsOneWidget);
    });

    testWidgets('pops back to the opener when the chat was pushed', (
      tester,
    ) async {
      final r = router(initialLocation: '/home');
      addTearDown(r.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: r));
      r.pushNamed(ExchangeSupportChatFacade.routeName);
      await tester.pumpAndSettle();
      expect(find.text('support'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(exits, 0);
      expect(find.text('home'), findsOneWidget);
    });
  });
}
