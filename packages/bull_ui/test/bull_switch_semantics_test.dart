import 'dart:ui' show Tristate;

import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

/// A switch sitting next to its caption, the shape every settings row uses.
Widget _captionedRow(Widget switchControl) => wrapWithTheme(
  Scaffold(
    body: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const ExcludeSemantics(child: Text('Internal Swap')),
        switchControl,
      ],
    ),
  ),
);

void main() {
  group('BullSwitch accessible name', () {
    testWidgets('announces its caption with the on/off state', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _captionedRow(
          BullSwitch(
            value: true,
            onChanged: (_) {},
            semanticLabel: 'Internal Swap',
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(Switch));
      expect(node.label, 'Internal Swap');
      expect(node.flagsCollection.isToggled, Tristate.isTrue);
      semantics.dispose();
    });

    testWidgets('is reachable by its caption', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _captionedRow(
          BullSwitch(
            value: false,
            onChanged: (_) {},
            semanticLabel: 'Internal Swap',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Internal Swap'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('satisfies the labeled tap-target guideline', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _captionedRow(
          BullSwitch(
            value: false,
            onChanged: (_) {},
            semanticLabel: 'Internal Swap',
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('reaches the 48 dp minimum tap target', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _captionedRow(
          BullSwitch(
            value: false,
            onChanged: (_) {},
            semanticLabel: 'Internal Swap',
          ),
        ),
      );

      final size = tester.getSize(find.byType(Switch));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      semantics.dispose();
    });

    testWidgets('an unnamed switch still reaches the 48 dp target', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(
            body: Center(child: BullSwitch(value: false, onChanged: (_) {})),
          ),
        ),
      );

      final size = tester.getSize(find.byType(Switch));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('a switch without a caption keeps its single node', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(
          MergeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Exchange fallback'),
                BullSwitch(value: false, onChanged: (_) {}),
              ],
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(Switch));
      expect(node.label, 'Exchange fallback');
      expect(find.byType(MergeSemantics), findsNWidgets(1));
      semantics.dispose();
    });
  });
}
