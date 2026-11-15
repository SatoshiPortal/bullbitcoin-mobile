import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'injected network refusal redirects before exchange presentation',
    (tester) async {
      var checks = 0;
      final router = GoRouter(
        initialLocation: ExchangeRoute.exchangeLanding.path,
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const Text('home')),
          ...ExchangeRouter.routes(
            ExchangeRouterConfig(
              networkUnavailable: () async {
                checks++;
                return true;
              },
              isSuperuser: (_) => false,
              homePath: '/home',
              buildHomeCards: () => [],
              onHomeRefresh: () {},
              onExit: (_) {},
              onOpenSettings: (_) {},
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(checks, 1);
    },
  );
}
