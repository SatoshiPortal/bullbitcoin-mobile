import 'package:bull_exchange/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final pushed in [false, true]) {
    testWidgets('back on a screen opened with push: $pushed', (tester) async {
      var exits = 0;
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/auth',
            builder: (_, _) => ExchangeExitOnBack(
              onExit: () => exits++,
              child: const Text('auth'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      pushed ? router.push('/auth') : router.go('/auth');
      await tester.pumpAndSettle();

      // `true`: the app handled the gesture, so the system keeps it open.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(exits, pushed ? 0 : 1);
      expect(find.text('home'), pushed ? findsOneWidget : findsNothing);
    });
  }
}
