import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullLabeledTextInput', () {
    TextField field(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField));

    testWidgets('renders the label and reports typed text', (tester) async {
      String? typed;
      await tester.pumpWidget(
        wrapWithTheme(
          BullLabeledTextInput(
            label: 'Label',
            value: '',
            onChanged: (v) => typed = v,
          ),
        ),
      );

      expect(find.text('Label'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello');

      expect(typed, 'hello');
    });

    testWidgets('disables the field when onChanged is null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullLabeledTextInput(
            label: 'Label',
            value: 'fixed',
            onChanged: null,
          ),
        ),
      );

      expect(field(tester).enabled, isFalse);
    });

    testWidgets('passes the secret-field settings through to the TextField', (
      tester,
    ) async {
      // The BIP39 passphrase field relies on these: the IME must not learn,
      // suggest or rewrite the value.
      await tester.pumpWidget(
        wrapWithTheme(
          BullLabeledTextInput(
            label: 'Passphrase',
            value: '',
            onChanged: (_) {},
            enableSuggestions: false,
            autocorrect: false,
            smartQuotesType: SmartQuotesType.disabled,
            smartDashesType: SmartDashesType.disabled,
          ),
        ),
      );

      final f = field(tester);
      expect(f.enableSuggestions, isFalse);
      expect(f.autocorrect, isFalse);
      expect(f.smartQuotesType, SmartQuotesType.disabled);
      expect(f.smartDashesType, SmartDashesType.disabled);
      expect(f.enableIMEPersonalizedLearning, isFalse);
    });
  });
}
