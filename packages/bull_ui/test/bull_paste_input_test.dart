import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('accepts exact multiline text without input rewriting', (
    tester,
  ) async {
    var value = '';
    await tester.pumpWidget(
      wrapWithTheme(
        BullPasteInput(
          text: value,
          hint: 'Paste value',
          onChanged: (next) => value = next,
        ),
      ),
    );

    const input = "[deadbeef/48'/0'/0'/2']xpub/<0;1>/*\nsecond line";
    await tester.enterText(find.byType(TextField), input);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(value, input);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.smartQuotesType, SmartQuotesType.disabled);
    expect(field.smartDashesType, SmartDashesType.disabled);
  });

  testWidgets('shows the optional scan action', (tester) async {
    var scanned = false;
    await tester.pumpWidget(
      wrapWithTheme(
        BullPasteInput(
          text: '',
          hint: 'Paste value',
          onChanged: (_) {},
          onScan: () => scanned = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.qr_code_scanner));

    expect(scanned, isTrue);
  });
}
