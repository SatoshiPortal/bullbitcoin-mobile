import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Future<void> pumpInput(
    WidgetTester tester, {
    bool onlyNumbers = false,
    bool obscure = false,
    int? maxLines,
  }) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullInputText(
          value: '',
          onlyNumbers: onlyNumbers,
          obscure: obscure,
          maxLines: maxLines,
          onChanged: (_) {},
        ),
      ),
    );
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
}
