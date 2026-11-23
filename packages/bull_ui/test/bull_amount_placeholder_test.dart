import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

double alphabeticBaseline(RenderBox box) {
  final baseline = box.getDryBaseline(
    BoxConstraints.tight(box.size),
    TextBaseline.alphabetic,
  );
  if (baseline == null) throw StateError('Expected a text baseline');
  return box.localToGlobal(Offset(0, baseline)).dy;
}

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'empty and filled numbers keep their unit gap and centre in ${direction.name}',
      (tester) async {
        final canonical = TextEditingController();
        addTearDown(canonical.dispose);
        await tester.pumpWidget(
          wrapWithTheme(
            Directionality(
              textDirection: direction,
              child: Center(
                child: SizedBox(
                  width: 390,
                  child: BullAmountInput(
                    canonicalUnit: BitcoinUnit.sats,
                    amountController: canonical,
                    framed: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final hint = tester.renderObject<RenderParagraph>(find.text('0'));
        final hintBox = hint
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 1),
            )
            .single;
        final hintLeft = hint.localToGlobal(Offset(hintBox.left, 0)).dx;
        final hintRight = hint.localToGlobal(Offset(hintBox.right, 0)).dx;
        final emptyUnit = tester.getRect(find.text('sats'));
        final unitParagraph = tester.renderObject<RenderParagraph>(
          find.text('sats'),
        );
        expect(
          alphabeticBaseline(hint),
          closeTo(alphabeticBaseline(unitParagraph), 0.1),
        );
        final ltr = direction == TextDirection.ltr;
        final emptyGap = ltr
            ? emptyUnit.left - hintRight
            : hintLeft - emptyUnit.right;
        final centre = tester.getRect(find.byType(BullAmountInput)).center.dx;
        final emptyCentre = ltr
            ? (hintLeft + emptyUnit.right) / 2
            : (emptyUnit.left + hintRight) / 2;
        canonical.text = '10000';
        await tester.pumpAndSettle();
        final field = tester.widget<EditableText>(find.byType(EditableText));
        final editable = tester
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable;
        final boxes = editable.getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: field.controller.text.length,
          ),
        );
        final numberLeft = editable
            .localToGlobal(Offset(boxes.first.left, 0))
            .dx;
        final numberRight = editable
            .localToGlobal(Offset(boxes.last.right, 0))
            .dx;
        final filledUnit = tester.getRect(find.text('sats'));
        final filledUnitParagraph = tester.renderObject<RenderParagraph>(
          find.text('sats'),
        );
        expect(
          alphabeticBaseline(editable),
          closeTo(alphabeticBaseline(filledUnitParagraph), 0.1),
        );
        final filledGap = ltr
            ? filledUnit.left - numberRight
            : numberLeft - filledUnit.right;
        final filledCentre = ltr
            ? (numberLeft + filledUnit.right) / 2
            : (filledUnit.left + numberRight) / 2;
        expect(emptyGap, closeTo(filledGap, 0.1));
        expect(emptyCentre, closeTo(centre, 2.1));
        expect(filledCentre, closeTo(centre, 2.1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'short number retains its editing target and equivalent stays inert',
    (tester) async {
      final canonical = TextEditingController();
      final focus = FocusNode();
      addTearDown(canonical.dispose);
      addTearDown(focus.dispose);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrapWithTheme(
            Center(
              child: SizedBox(
                width: 390,
                child: BullAmountInput(
                  canonicalUnit: BitcoinUnit.sats,
                  amountController: canonical,
                  amountEquivalent: '31.25 CAD',
                  focusNode: focus,
                  framed: true,
                ),
              ),
            ),
          ),
        );
        final target = tester.getRect(find.byType(TextField));
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
        await tester.tapAt(Offset(target.left + 1, target.center.dy));
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        expect(tester, meetsGuideline(androidTapTargetGuideline));
        await tester.enterText(find.byType(TextField), '1');
        await tester.pump();
        await tester.tap(find.text('sats'));
        await tester.pump();
        expect(canonical.text, '1');
        expect(find.text('BTC'), findsOneWidget);
        await tester.tap(find.text('≈ 31.25 CAD'));
        await tester.pumpAndSettle();
        expect(canonical.text, '1');
        expect(
          find.byType(BullPickerSheet<BullPickerItem<String>>),
          findsNothing,
        );
      } finally {
        semantics.dispose();
      }
    },
  );
}
