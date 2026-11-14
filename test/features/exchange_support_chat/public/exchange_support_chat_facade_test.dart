import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _OpenChat extends StatelessWidget {
  const _OpenChat(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () =>
            ExchangeSupportChatFacade.open(context, initialMessage: 'Order 42'),
        child: Text(label),
      ),
    );
  }
}

/// Mirrors the app: the wallet home lives in a shell, while the support chat
/// and screens like settings are top-level routes pushed above that shell.
GoRouter _router() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (_, _, child) => child,
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const _OpenChat('home')),
        ],
      ),
      GoRoute(
        name: ExchangeSupportChatFacade.routeName,
        path: '/support-chat',
        builder: (_, state) {
          final draft = state.extra as ExchangeSupportChatDraft?;
          return Scaffold(body: Text('chat ${draft?.initialMessage}'));
        },
      ),
      GoRoute(
        name: 'settings',
        path: '/settings',
        builder: (_, _) => const _OpenChat('settings'),
      ),
    ],
  );
}

Future<GoRouter> _pump(WidgetTester tester) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('ExchangeSupportChatFacade.open', () {
    testWidgets('from inside the shell, back returns to the opener', (
      tester,
    ) async {
      final router = await _pump(tester);

      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();

      expect(find.text('chat Order 42'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('from a screen above the shell, back returns to that screen', (
      tester,
    ) async {
      final router = await _pump(tester);
      router.pushNamed('settings');
      await tester.pumpAndSettle();

      await tester.tap(find.text('settings'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('chat Order 42'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('settings'), findsOneWidget);
    });
  });
}
