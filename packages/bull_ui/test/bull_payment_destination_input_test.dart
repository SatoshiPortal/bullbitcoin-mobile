import 'dart:ui' show SemanticsAction;

import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Widget field({
    String value = '',
    String? label = 'Destination',
    Widget? validAddress,
    String? error,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
    VoidCallback? onPaste,
    VoidCallback? onScan,
    VoidCallback? onClear,
  }) => wrapWithTheme(
    BullPaymentDestinationInput(
      value: value,
      onChanged: onChanged ?? (_) {},
      label: label,
      hint: 'Address',
      pasteLabel: 'Paste',
      scanLabel: 'Scan',
      clearLabel: 'Clear',
      onPaste: onPaste ?? () {},
      onScan: onScan ?? () {},
      onClear: onClear ?? () {},
      validAddress: validAddress,
      kind: 'Bitcoin address',
      error: error,
      keyboardType: keyboardType,
    ),
  );

  testWidgets('the destination name stays on the editable node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final value in ['', 'bc1example']) {
      await tester.pumpWidget(field(value: value));
      final fieldFinder = find.byType(EditableText);
      expect(
        tester.getSemantics(fieldFinder).getSemanticsData().label,
        'Destination',
      );
      await tester.tap(fieldFinder);
      await tester.pump();
      final editor = tester.getSemantics(fieldFinder);
      final data = editor.getSemanticsData();
      expect(data.label, 'Destination');
      expect(data.value, value);
      expect(data.flagsCollection.isTextField, isTrue);
      expect(data.hasAction(SemanticsAction.setText), isTrue);
      expect(find.bySemanticsLabel('Paste'), findsOneWidget);
      expect(find.bySemanticsLabel('Scan'), findsOneWidget);
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
    }

    await tester.pumpWidget(field(label: null, value: 'bc1example'));
    final editor = tester.getSemantics(find.byType(EditableText));
    expect(editor.getSemanticsData().label, 'Address');
    semantics.dispose();
  });

  testWidgets('invalid input stays editable with native keyboard and actions', (
    tester,
  ) async {
    var typed = '';
    var pasted = false;
    var scanned = false;
    await tester.pumpWidget(
      field(
        value: 'bad',
        error: 'Invalid address',
        keyboardType: TextInputType.emailAddress,
        onChanged: (value) => typed = value,
        onPaste: () => pasted = true,
        onScan: () => scanned = true,
      ),
    );
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.keyboardType, TextInputType.emailAddress);
    expect(input.autocorrect, isFalse);
    expect(input.enableSuggestions, isFalse);
    expect(input.smartQuotesType, SmartQuotesType.disabled);
    expect(input.smartDashesType, SmartDashesType.disabled);
    expect(input.textCapitalization, TextCapitalization.none);
    expect(find.text('Invalid address'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'new value');
    expect(typed, 'new value');
    await tester.tap(find.text('Paste'));
    await tester.tap(find.text('Scan'));
    expect(pasted, isTrue);
    expect(scanned, isTrue);
  });

  testWidgets('valid value shows supplied viewer and clear action', (
    tester,
  ) async {
    var cleared = false;
    await tester.pumpWidget(
      field(
        value: 'bc1example',
        validAddress: const Text('Address viewer'),
        onClear: () => cleared = true,
      ),
    );
    expect(find.text('Address viewer'), findsOneWidget);
    expect(find.text('Bitcoin address'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Paste'), findsNothing);
    expect(find.text('Scan'), findsNothing);
    await tester.tap(find.byTooltip('Clear'));
    expect(cleared, isTrue);
  });

  testWidgets(
    'external updates synchronize without resetting typed selection',
    (tester) async {
      await tester.pumpWidget(field(value: 'abc'));
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller;
      controller?.selection = const TextSelection.collapsed(offset: 1);
      await tester.pumpWidget(field(value: 'abc'));
      expect(controller?.selection.baseOffset, 1);
      await tester.pumpWidget(field(value: 'replacement'));
      expect(controller?.text, 'replacement');
      expect(controller?.selection.baseOffset, 'replacement'.length);
    },
  );

  testWidgets(
    'unlabelled disabled field starts at its input and ignores actions',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrapWithTheme(
          BullPaymentDestinationInput(
            value: '',
            onChanged: (_) {},
            hint: 'Address',
            pasteLabel: 'Paste',
            scanLabel: 'Scan',
            clearLabel: 'Clear',
            onPaste: () => tapped = true,
            onScan: () => tapped = true,
            onClear: () => tapped = true,
            enabled: false,
          ),
        ),
      );
      expect(tester.getTopLeft(find.byType(TextField)).dy, 1);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.tap(find.text('Paste'), warnIfMissed: false);
      expect(tapped, isFalse);
    },
  );
}
