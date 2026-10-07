import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // The flow used to *replace* the settings route: the button then lived
  // inside the RecoverBull settings page, itself a `/recoverbull-flows`
  // route, and stacking two flows would have run two blocs and two Tor
  // sessions. The button now lives in Backup settings, so the flow must be
  // pushed instead, or the back arrow has nothing to return to.
  testWidgets('View Vault Key pushes its RecoverBull flow over settings', (
    tester,
  ) async {
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/recoverbull-settings-test',
      routes: [
        GoRoute(
          path: '/recoverbull-settings-test',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => openRecoverBullFlow(
                context,
                flow: RecoverBullFlow.viewVaultKey,
              ),
              child: const Text('View Vault Key'),
            ),
          ),
        ),
        GoRoute(
          name: RecoverBullRoute.recoverbullFlows.name,
          path: RecoverBullRoute.recoverbullFlows.path,
          builder: (context, state) {
            final extra = state.extra! as RecoverBullFlowsExtra;
            return Text(extra.flow.name);
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('View Vault Key'));
    await tester.pumpAndSettle();

    expect(find.text(RecoverBullFlow.viewVaultKey.name), findsOneWidget);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('View Vault Key'), findsOneWidget);
    expect(find.text(RecoverBullFlow.viewVaultKey.name), findsNothing);
  });
}
