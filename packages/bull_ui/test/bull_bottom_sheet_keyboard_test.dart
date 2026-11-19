import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final avoidKeyboard in [false, true]) {
    testWidgets('keyboard avoidance is opt-in: $avoidKeyboard', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => BullInlineTextButton(
              child: const Text('Open sheet'),
              onPressed: () => BullBottomSheet.show<void>(
                context: context,
                avoidKeyboard: avoidKeyboard,
                child: const SizedBox(
                  height: 100,
                  child: Text('Message input'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      final before = tester.getBottomLeft(find.byType(BullBottomSheet)).dy;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final after = tester.getBottomLeft(find.byType(BullBottomSheet)).dy;
      expect(before, 844);
      expect(after, avoidKeyboard ? 544 : 844);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.byType(BullBottomSheet)).dy, before);
    });
  }
}
