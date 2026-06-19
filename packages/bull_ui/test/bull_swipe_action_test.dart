import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullSwipeAction', () {
    testWidgets('commits when dragged past 60% of reveal width', (
      tester,
    ) async {
      var fired = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullSwipeAction(
            actionLabel: 'Freeze',
            actionIcon: BullIcons.acUnit,
            actionColor: const Color(0xFF0063F7),
            onAction: () => fired++,
            child: const SizedBox(height: 60, child: Text('row')),
          ),
        ),
      );

      // Reveal width defaults to 92; 60% = 55.2. Drag 70px left -> commits.
      await tester.drag(find.text('row'), const Offset(-70, 0));
      await tester.pumpAndSettle();

      expect(fired, 1);
    });

    testWidgets('snaps back and does not fire below 60%', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullSwipeAction(
            actionLabel: 'Freeze',
            actionIcon: BullIcons.acUnit,
            actionColor: const Color(0xFF0063F7),
            onAction: () => fired++,
            child: const SizedBox(height: 60, child: Text('row')),
          ),
        ),
      );

      // Drag only 30px (< 55.2) -> snaps back, no fire.
      await tester.drag(find.text('row'), const Offset(-30, 0));
      await tester.pumpAndSettle();

      expect(fired, 0);
    });

    testWidgets('is inert when disabled', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullSwipeAction(
            enabled: false,
            actionLabel: 'Freeze',
            actionIcon: BullIcons.acUnit,
            actionColor: const Color(0xFF0063F7),
            onAction: () => fired++,
            child: const SizedBox(height: 60, child: Text('row')),
          ),
        ),
      );

      await tester.drag(find.text('row'), const Offset(-90, 0));
      await tester.pumpAndSettle();

      expect(fired, 0);
    });
  });
}
