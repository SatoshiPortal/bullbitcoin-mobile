import 'package:ark/ark.dart';
import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:bull_ark/src/ui/ark_operation_review_screen.dart';
import 'package:bull_ui/testing.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullDialog, BullText, BullTopBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_result_layout_red_test.dart' show acceptedResult;

BullButton action(WidgetTester tester, String name) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, name));
void main() {
  testWidgets(
    'result detail system Back stays local and host Done pops once from details',
    (tester) async {
      final rig = await acceptedResult();
      var done = 0;
      late GoRouter router;
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Text('Origin'),
            routes: [
              GoRoute(
                path: 'result',
                builder: (_, _) => ArkOperationReviewScreen(
                  cubit: rig.cubit,
                  onReconcile: () {},
                  onDone: () {
                    ++done;
                    router.pop();
                  },
                ),
              ),
            ],
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: ThemeData(extensions: testBullExtensions),
            locale: const Locale('en'),
            supportedLocales: ArkLocalizations.supportedLocales,
            localizationsDelegates: const [
              ArkLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
          ),
        );
        router.push<void>('/result');
        await tester.pumpAndSettle();
        action(tester, 'Operation details').onPressed();
        await tester.pumpAndSettle();
        expect(find.text('accepted-operation'), findsOneWidget);
        expect(
          find.text(
            'Request completed. Chain settlement and round completion are separate.',
          ),
          findsOneWidget,
        );
        expect(find.text('Renewal started'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.canPop(), isTrue);
        expect(find.text('Renewal started'), findsOneWidget);
        action(tester, 'Operation details').onPressed();
        await tester.pumpAndSettle();
        tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack?.call();
        await tester.pumpAndSettle();
        expect(find.text('Renewal started'), findsOneWidget);
        expect(router.canPop(), isTrue);
        action(tester, 'Operation details').onPressed();
        await tester.pumpAndSettle();
        final oldDone = action(tester, 'Done').onPressed;
        final cover = BullDialog.show<void>(
          context: tester.element(find.text('accepted-operation')),
          builder: (_) => const BullText('Cover'),
        );
        await tester.pumpAndSettle();
        oldDone();
        await tester.pumpAndSettle();
        expect(find.text('Cover'), findsOneWidget);
        expect(done, 0);
        Navigator.of(tester.element(find.text('Cover'))).pop();
        await cover;
        await tester.pumpAndSettle();
        final delayedDone = action(tester, 'Done').onPressed;
        delayedDone();
        final lateCover = BullDialog.show<void>(
          context: tester.element(find.text('accepted-operation')),
          builder: (_) => const BullText('Late cover'),
        );
        await tester.pumpAndSettle();
        expect(done, 0);
        Navigator.of(tester.element(find.text('Late cover'))).pop();
        await lateCover;
        await tester.pumpAndSettle();
        delayedDone();
        await tester.pumpAndSettle();
        expect(done, 0);
        action(tester, 'Done').onPressed();
        await tester.pumpAndSettle();
        expect(done, 1);
        expect(router.canPop(), isFalse);
        expect(find.text('Origin'), findsOneWidget);
        oldDone();
        await tester.pumpAndSettle();
        expect(done, 1);
        expect(rig.client.calls, ['quote', 'submit']);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        router.dispose();
      }
    },
  );
  testWidgets('missing host Done retains an explicit guarded Refresh', (
    tester,
  ) async {
    final rig = await acceptedResult();
    var refresh = 0;
    await tester.pumpWidget(
      app(
        ArkOperationReviewScreen(
          cubit: rig.cubit,
          onReconcile: () => refresh++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(BullButton, 'Done'), findsNothing);
    action(tester, 'Operation details').onPressed();
    await tester.pumpAndSettle();
    final refreshAction = action(tester, 'Refresh').onPressed;
    refreshAction();
    await tester.pumpAndSettle();
    refreshAction();
    await tester.pumpAndSettle();
    expect(refresh, 1);
    expect(action(tester, 'Refresh').disabled, isFalse);
    action(tester, 'Refresh').onPressed();
    await tester.pumpAndSettle();
    expect(refresh, 2);
    tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack?.call();
    await tester.pumpAndSettle();
    expect(find.text('Renewal started'), findsOneWidget);
    refreshAction();
    await tester.pumpAndSettle();
    expect(refresh, 2);
    expect(rig.client.calls, ['quote', 'submit']);
  });
  testWidgets('owner replacement retires saved result and detail actions', (
    tester,
  ) async {
    final first = await acceptedResult(), second = await acceptedResult();
    var firstDone = 0, secondDone = 0;
    await tester.pumpWidget(
      app(
        ArkOperationReviewScreen(
          cubit: first.cubit,
          onReconcile: () {},
          onDone: () => firstDone++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final oldDetails = action(tester, 'Operation details').onPressed;
    oldDetails();
    await tester.pumpAndSettle();
    final oldDone = action(tester, 'Done').onPressed;
    await tester.pumpWidget(
      app(
        ArkOperationReviewScreen(
          cubit: second.cubit,
          onReconcile: () {},
          onDone: () => secondDone++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    oldDone();
    oldDetails();
    await tester.pumpAndSettle();
    expect(firstDone, 0);
    expect(secondDone, 0);
    expect(find.text('accepted-operation'), findsNothing);
    action(tester, 'Done').onPressed();
    await tester.pumpAndSettle();
    expect(secondDone, 1);
    expect(first.client.calls, ['quote', 'submit']);
    expect(second.client.calls, ['quote', 'submit']);
  });
  testWidgets(
    'result footer remains reachable with large text at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rig = await acceptedResult();
      await tester.pumpWidget(
        app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ArkOperationReviewScreen(
              cubit: rig.cubit,
              onReconcile: () {},
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.widgetWithText(BullButton, 'Done')).dy,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
      action(tester, 'Operation details').onPressed();
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.widgetWithText(BullButton, 'Done')).dy,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final status in ArkOperationStatus.values.where(
    (s) => s != ArkOperationStatus.succeeded,
  )) {
    testWidgets('non-success $status cannot get the accepted result', (
      tester,
    ) async {
      final rig = await acceptedResult(status: status);
      await tester.pumpWidget(
        app(
          ArkOperationReviewScreen(
            cubit: rig.cubit,
            onReconcile: () {},
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(BullButton, 'Operation details'),
        findsNothing,
      );
      expect(find.text('Renewal started'), findsNothing);
    });
  }
}
