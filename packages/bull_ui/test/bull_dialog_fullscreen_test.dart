import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    bool fullscreen = true,
    bool dismissible = true,
  }) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => BullInlineTextButton(
            onPressed: () => BullDialog.show<void>(
              context: context,
              fullscreen: fullscreen,
              isDismissible: dismissible,
              barrierColor: testBullTheme.onSurfaceFixed.withValues(
                alpha: 0.88,
              ),
              builder: (_) => Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: ColoredBox(
                    color: testBullTheme.surface,
                    child: const Text('QR overlay'),
                  ),
                ),
              ),
            ),
            child: const Text('Open overlay'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open overlay'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'fullscreen chrome keeps panel taps and passes outside taps to the scrim',
    (tester) async {
      await open(tester);
      expect(
        tester.getSize(find.byType(BullDialog)),
        tester.view.physicalSize / tester.view.devicePixelRatio,
      );
      final barriers = tester.widgetList<ModalBarrier>(
        find.byType(ModalBarrier),
      );
      expect(
        barriers.any(
          (barrier) =>
              barrier.color ==
                  testBullTheme.onSurfaceFixed.withValues(alpha: 0.88) &&
              barrier.dismissible,
        ),
        isTrue,
      );
      await tester.tapAt(tester.getCenter(find.byType(BullDialog)));
      await tester.pumpAndSettle();
      expect(find.text('QR overlay'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.text('QR overlay'), findsNothing);
    },
  );

  testWidgets('a non-dismissible fullscreen overlay retains outside taps', (
    tester,
  ) async {
    await open(tester, dismissible: false);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('QR overlay'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('QR overlay'), findsNothing);
  });

  testWidgets('fullscreen fills the viewport including safe-area insets', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.resetPadding);
    await open(tester);
    expect(tester.getTopLeft(find.byType(BullDialog)), Offset.zero);
    expect(
      tester.getSize(find.byType(BullDialog)),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
  });

  testWidgets('ordinary dialog chrome remains the default', (tester) async {
    await open(tester, fullscreen: false);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .width,
      lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio),
    );
  });
}
