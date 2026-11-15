import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/public/recoverbull_feature.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final flow in RecoverBullFlow.values) {
    testWidgets('opens ${flow.name} without a shell locator', (tester) async {
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
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(flow.name), findsOneWidget);
    });
  }
}
