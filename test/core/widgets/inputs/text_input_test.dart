import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Future<TextEditingController> pumpInput(
    WidgetTester tester, {
    bool digitsOnly = false,
    bool onlyNumbers = false,
  }) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      wrap(
        BBInputText(
          controller: controller,
          value: '',
          onChanged: (_) {},
          digitsOnly: digitsOnly,
          onlyNumbers: onlyNumbers,
        ),
      ),
    );
    return controller;
  }

  group('BBInputText', () {
    testWidgets('digitsOnly rejects a decimal point and letters', (
      tester,
    ) async {
      final controller = await pumpInput(tester, digitsOnly: true);

      await tester.enterText(find.byType(TextField), '1.5a2');

      expect(controller.text, '152');
    });

    testWidgets('digitsOnly uses an integer keyboard', (tester) async {
      await pumpInput(tester, digitsOnly: true);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
    });

    testWidgets('onlyNumbers still accepts a decimal point', (tester) async {
      final controller = await pumpInput(tester, onlyNumbers: true);

      await tester.enterText(find.byType(TextField), '1.5');

      expect(controller.text, '1.5');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
    });
  });
}
