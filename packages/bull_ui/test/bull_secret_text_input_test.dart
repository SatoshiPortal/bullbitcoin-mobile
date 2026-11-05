import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

const _secret = 'correct horse';

void main() {
  group('BullSecretTextInput', () {
    String? reported;

    Future<void> pump(WidgetTester tester) async {
      reported = null;
      await tester.pumpWidget(
        wrapWithTheme(
          BullSecretTextInput(
            label: 'Passphrase',
            hint: 'Optional passphrase',
            onChanged: (value) => reported = value,
            showLabel: 'Show passphrase',
            hideLabel: 'Hide passphrase',
          ),
        ),
      );
    }

    TextField field(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField));

    Future<void> toggle(WidgetTester tester, String tooltip) async {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
    }

    /// Every label, value, hint and tooltip published in the semantics tree.
    List<String> semanticsStrings(WidgetTester tester) {
      final strings = <String>[];
      bool visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        strings.addAll([data.label, data.value, data.hint, data.tooltip]);
        node.visitChildren(visit);
        return true;
      }

      final root = tester
          .getSemantics(find.byType(Scaffold))
          .owner
          ?.rootSemanticsNode;
      if (root != null) visit(root);
      return strings;
    }

    testWidgets('reports what is typed', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), _secret);
      expect(reported, _secret);
    });

    testWidgets('keeps the value away from the IME', (tester) async {
      await pump(tester);

      final f = field(tester);
      expect(f.enableSuggestions, isFalse);
      expect(f.autocorrect, isFalse);
      expect(f.enableIMEPersonalizedLearning, isFalse);
      expect(f.keyboardType, TextInputType.visiblePassword);
      expect(f.autofillHints, isEmpty);
      expect(f.smartQuotesType, SmartQuotesType.disabled);
      expect(f.smartDashesType, SmartDashesType.disabled);
    });

    testWidgets(
      'keeps every keyboard on iOS, where visiblePassword is ASCII only',
      (tester) async {
        await pump(tester);
        expect(field(tester).keyboardType, TextInputType.text);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('is obscured until the toggle reveals it, and hides again', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), _secret);

      expect(field(tester).obscureText, isTrue);
      expect(find.byTooltip('Hide passphrase'), findsNothing);

      await toggle(tester, 'Show passphrase');
      expect(field(tester).obscureText, isFalse);
      expect(find.byTooltip('Show passphrase'), findsNothing);
      // Revealing never edits the value.
      expect(field(tester).controller?.text, _secret);

      await toggle(tester, 'Hide passphrase');
      expect(field(tester).obscureText, isTrue);
    });

    testWidgets('never publishes the value to the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await tester.enterText(find.byType(TextField), _secret);
      await tester.pump();

      // Hidden: not even one dot per character, which would leak the length.
      final hidden = semanticsStrings(tester);
      expect(hidden, isNot(contains(contains('horse'))));
      expect(hidden, isNot(contains(contains('•'))));

      // Revealed on screen, still absent from the tree.
      await toggle(tester, 'Show passphrase');
      expect(semanticsStrings(tester), isNot(contains(contains('horse'))));

      // A screen reader still finds the field by name, and the toggle.
      expect(
        tester.getSemantics(find.byType(TextField)),
        matchesSemantics(
          label: 'Passphrase',
          hint: 'Optional passphrase',
          isTextField: true,
          isObscured: true,
          isFocusable: true,
          // Still focused from typing.
          isFocused: true,
          hasTapAction: true,
        ),
      );
      expect(semanticsStrings(tester), contains('Hide passphrase'));
      handle.dispose();
    });

    testWidgets('offers no selection, so nothing can be copied out', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), _secret);
      await toggle(tester, 'Show passphrase');

      expect(field(tester).enableInteractiveSelection, isFalse);

      await tester.longPress(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsNothing);
      expect(find.text('Select all'), findsNothing);
      expect(field(tester).controller?.selection.isCollapsed, isTrue);
    });

    testWidgets('a tap from a screen reader focuses the field', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      tester.semantics.tap(find.semantics.byFlag(SemanticsFlag.isTextField));
      await tester.pump();

      expect(field(tester).focusNode?.hasFocus, isTrue);
      handle.dispose();
    });
  });
}
