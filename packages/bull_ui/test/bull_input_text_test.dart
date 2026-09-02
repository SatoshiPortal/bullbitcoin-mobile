import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Future<TextEditingController> pumpInput(
    WidgetTester tester, {
    bool onlyNumbers = false,
    bool digitsOnly = false,
    bool obscure = false,
    int? maxLines,
  }) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      wrapWithTheme(
        BullInputText(
          controller: controller,
          value: '',
          onlyNumbers: onlyNumbers,
          digitsOnly: digitsOnly,
          obscure: obscure,
          maxLines: maxLines,
          onChanged: (_) {},
        ),
      ),
    );
    return controller;
  }

  TextField findTextField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  group('BullInputText line behaviour', () {
    testWidgets('numeric fields are single-line', (tester) async {
      await pumpInput(tester, onlyNumbers: true);

      expect(findTextField(tester).maxLines, 1);
    });

    testWidgets('numeric fields submit instead of inserting a newline', (
      tester,
    ) async {
      await pumpInput(tester, onlyNumbers: true);

      expect(findTextField(tester).textInputAction, TextInputAction.done);
    });

    testWidgets('numeric fields reject newline characters', (tester) async {
      await pumpInput(tester, onlyNumbers: true);

      await tester.enterText(find.byType(TextField), '10\n\n20');
      await tester.pump();

      expect(find.text('1020'), findsOneWidget);
    });

    testWidgets('obscured fields stay single-line', (tester) async {
      await pumpInput(tester, obscure: true);

      expect(findTextField(tester).maxLines, 1);
    });

    testWidgets('free-text fields remain multiline', (tester) async {
      await pumpInput(tester);

      final textField = findTextField(tester);
      expect(textField.maxLines, isNull);
      expect(textField.textInputAction, TextInputAction.newline);
    });

    testWidgets('an explicit maxLines wins over the numeric default', (
      tester,
    ) async {
      await pumpInput(tester, onlyNumbers: true, maxLines: 3);

      expect(findTextField(tester).maxLines, 3);
    });
  });

  group('BullInputText numeric input', () {
    testWidgets('digitsOnly rejects a decimal point and letters', (
      tester,
    ) async {
      final controller = await pumpInput(tester, digitsOnly: true);

      await tester.enterText(find.byType(TextField), '1.5a2');

      expect(controller.text, '152');
    });

    testWidgets('digitsOnly uses an integer keyboard', (tester) async {
      await pumpInput(tester, digitsOnly: true);

      expect(findTextField(tester).keyboardType, TextInputType.number);
    });

    testWidgets('onlyNumbers still accepts a decimal point', (tester) async {
      final controller = await pumpInput(tester, onlyNumbers: true);

      await tester.enterText(find.byType(TextField), '1.5');

      expect(controller.text, '1.5');
      expect(
        findTextField(tester).keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
    });
  });
}
