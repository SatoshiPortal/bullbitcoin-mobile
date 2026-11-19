import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show TextField;

import 'test_app.dart';

void main() {
  testWidgets('default input keeps its effective alignment, fill and padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(BullInputText(value: '100000', onChanged: (_) {})),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textAlign, TextAlign.left);
    expect(field.decoration?.filled, true);
    expect(field.decoration?.contentPadding, const EdgeInsets.all(16));
    expect(field.controller?.text, '100000');
  });

  testWidgets('centered unfilled input preserves controlled amount edits', (
    tester,
  ) async {
    var value = '100000';
    Widget input() => wrapWithTheme(
      BullInputText(
        value: value,
        onChanged: (next) => value = next,
        textAlign: TextAlign.center,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        digitsOnly: true,
        maxLines: 1,
      ),
    );
    await tester.pumpWidget(input());
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textAlign, TextAlign.center);
    expect(field.decoration?.filled, false);
    expect(
      field.decoration?.contentPadding,
      const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
    );
    await tester.enterText(find.byType(TextField), '25000');
    await tester.pumpWidget(input());
    expect(value, '25000');
    value = '100000';
    await tester.pumpWidget(input());
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '100000',
    );
    expect(tester.takeException(), isNull);
  });
}
