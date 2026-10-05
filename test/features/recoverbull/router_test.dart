import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('View Vault Key replaces settings with its RecoverBull flow', (
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
    expect(router.canPop(), isFalse);
  });
}
