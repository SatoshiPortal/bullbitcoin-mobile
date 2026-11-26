// Keep new Send tests independent of the application package namespace.
import 'package:send/src/payment/ui/widgets/send_custom_fee_editor.dart';

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget shell(Widget child, {double scale = 1}) => MaterialApp(
    theme: ThemeData(
      extensions: testBullExtensions,
      textTheme: testBullTypography.toTextTheme(),
    ),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: child),
    ),
  );
  Widget editor({
    ValueChanged<String>? submit,
    FocusNode? focus,
    VoidCallback? back,
  }) => SendCustomFeeEditor(
    title: 'Custom fee',
    backLabel: 'Back',
    closeLabel: 'Close',
    modes: const {'Rate', 'Total'},
    selectedMode: 'Rate',
    value: '',
    unit: 'sat/vB',
    help: 'Enter a fee',
    doneLabel: 'Done',
    onMode: (_) {},
    onChanged: (_) {},
    onBack: back ?? () {},
    onClose: () {},
    onSubmit: submit,
    focusNode: focus,
  );

  testWidgets('invalid keyboard completion retains focus and raw input', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(shell(editor(focus: focus)));
    await tester.enterText(find.byType(TextField), '-0.25');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '-0.25',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid completion submits actual text once and releases focus', (
    tester,
  ) async {
    final values = <String>[];
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(shell(editor(focus: focus, submit: values.add)));
    await tester.enterText(find.byType(TextField), '0.333');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(values, ['0.333']);
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('Done on the iOS keyboard bar applies the value', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    final values = <String>[];
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(shell(editor(focus: focus, submit: values.add)));
    await tester.showKeyboard(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(values, ['']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Back on iOS cancels a typed fee instead of applying it', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    final values = <String>[];
    var backs = 0;
    await tester.pumpWidget(
      shell(editor(submit: values.add, back: () => backs++)),
    );
    await tester.showKeyboard(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(backs, 1);
    expect(values, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('translated segments fit at large text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      shell(
        BullSegmented(
          items: const {'Économique', 'Personnalisés', 'Rapide'},
          initialValue: 'Économique',
          onSelected: (_) {},
          fitLabels: true,
          height: 48,
        ),
        scale: 3,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final box = tester.getRect(find.byType(BullSegmented));
    for (final label in ['Économique', 'Personnalisés', 'Rapide']) {
      final text = tester.getRect(find.text(label));
      expect(text.top, greaterThanOrEqualTo(box.top));
      expect(text.bottom, lessThanOrEqualTo(box.bottom));
    }
  });
}
