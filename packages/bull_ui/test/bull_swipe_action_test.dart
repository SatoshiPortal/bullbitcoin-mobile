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

    testWidgets('action panel is only painted while the row is open', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullSwipeAction(
            actionLabel: 'Freeze',
            actionIcon: BullIcons.acUnit,
            actionColor: const Color(0xFF0063F7),
            onAction: () {},
            child: const SizedBox(height: 60, child: Text('row')),
          ),
        ),
      );

      // Closed: nothing to reveal, so the panel (and its label) is not painted —
      // it can't bleed through a translucent row above it.
      expect(find.text('Freeze'), findsNothing);

      // Partially open: the panel appears.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('row')),
      );
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(find.text('Freeze'), findsOneWidget);

      // Released below the commit threshold → snaps back closed → panel gone.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Freeze'), findsNothing);
    });
  });

  group('BullSwipeAction — leading action', () {
    BullSwipeAction build({
      required VoidCallback onAction,
      VoidCallback? onLeadingAction,
    }) {
      return BullSwipeAction(
        actionLabel: 'Freeze',
        actionIcon: BullIcons.acUnit,
        actionColor: const Color(0xFF0063F7),
        onAction: onAction,
        onLeadingAction: onLeadingAction,
        leadingActionLabel: onLeadingAction == null ? null : 'Sweep',
        leadingActionIcon: onLeadingAction == null ? null : BullIcons.callMerge,
        leadingActionColor: onLeadingAction == null
            ? null
            : const Color(0xFF00B37E),
        child: const SizedBox(height: 60, child: Text('row')),
      );
    }

    testWidgets('a rightward drag past 60% fires the leading action', (
      tester,
    ) async {
      var trailing = 0;
      var leading = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          build(onAction: () => trailing++, onLeadingAction: () => leading++),
        ),
      );

      await tester.drag(find.text('row'), const Offset(70, 0));
      await tester.pumpAndSettle();

      expect(leading, 1);
      expect(trailing, 0, reason: 'the two directions must not cross wires');
    });

    testWidgets('a rightward drag below 60% snaps back', (tester) async {
      var leading = 0;
      await tester.pumpWidget(
        wrapWithTheme(build(onAction: () {}, onLeadingAction: () => leading++)),
      );

      await tester.drag(find.text('row'), const Offset(30, 0));
      await tester.pumpAndSettle();

      expect(leading, 0);
    });

    testWidgets('the leading panel shows only while dragging right', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(build(onAction: () {}, onLeadingAction: () {})),
      );
      expect(find.text('Sweep'), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('row')),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(find.text('Sweep'), findsOneWidget);
      // The trailing panel must not be painted at the same time.
      expect(find.text('Freeze'), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Sweep'), findsNothing);
    });

    testWidgets('without a leading action the row will not move right', (
      tester,
    ) async {
      var trailing = 0;
      await tester.pumpWidget(wrapWithTheme(build(onAction: () => trailing++)));

      await tester.drag(find.text('row'), const Offset(90, 0));
      await tester.pumpAndSettle();

      // Unchanged behaviour for every existing caller: nothing fires, and no
      // panel was ever revealed.
      expect(trailing, 0);
      expect(find.text('Freeze'), findsNothing);
    });

    testWidgets('the trailing action still works alongside a leading one', (
      tester,
    ) async {
      var trailing = 0;
      var leading = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          build(onAction: () => trailing++, onLeadingAction: () => leading++),
        ),
      );

      await tester.drag(find.text('row'), const Offset(-70, 0));
      await tester.pumpAndSettle();

      expect(trailing, 1);
      expect(leading, 0);
    });
  });
}
