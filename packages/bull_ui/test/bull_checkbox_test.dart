import 'dart:ui' show SemanticsAction;

import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullCheckbox', () {
    testWidgets('toggles and reports the new value on tap', (tester) async {
      var checked = false;
      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return BullCheckbox(
                checked: checked,
                onChanged: (v) => setState(() => checked = v),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(BullCheckbox));
      await tester.pump();
      expect(checked, isTrue);

      await tester.tap(find.byType(BullCheckbox));
      await tester.pump();
      expect(checked, isFalse);
    });

    testWidgets('is inert when onChanged is null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const BullCheckbox(checked: false, onChanged: null)),
      );

      // No callback to fire; tapping must not throw.
      await tester.tap(find.byType(BullCheckbox));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('exposes a 48px accessible tap target', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(BullCheckbox(checked: true, onChanged: (_) {})),
      );

      // The 22px box stays as drawn; the touch target around it is 48×48.
      expect(tester.getSize(find.byType(BullCheckbox)), const Size(48, 48));
    });

    testWidgets('exposes a named checkable node, with no button role', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(
          BullCheckbox(
            checked: true,
            semanticLabel: 'Select coin',
            onChanged: (_) {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(BullCheckbox)),
        matchesSemantics(
          label: 'Select coin',
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('keeps the checked state without a label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(BullCheckbox(checked: false, onChanged: (_) {})),
      );

      expect(
        tester.getSemantics(find.byType(BullCheckbox)),
        matchesSemantics(
          hasCheckedState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('reports a disabled node when onChanged is null', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(const BullCheckbox(checked: true, onChanged: null)),
      );

      expect(
        tester.getSemantics(find.byType(BullCheckbox)),
        matchesSemantics(
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('toggles once per pointer tap, key press and semantic tap', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        wrapWithTheme(BullCheckbox(checked: false, onChanged: (_) => calls++)),
      );

      await tester.tap(find.byType(BullCheckbox));
      await tester.pump();
      expect(calls, 1);

      // Keyboard: reachable with Tab, activated with Space (ActivateIntent).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(calls, 2);

      final node = tester.getSemantics(find.byType(BullCheckbox));
      tester.binding.renderViews.first.owner?.semanticsOwner?.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(calls, 3);
    });
  });
}
