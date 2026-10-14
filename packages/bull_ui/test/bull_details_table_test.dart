import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullDetailsTableItem', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('renders the value in the bodyLarge style', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullDetailsTableItem(label: 'Fee', displayValue: '210 sats'),
        ),
      );

      final value = find.text('210 sats');
      final textTheme = Theme.of(tester.element(value)).textTheme;
      final style = tester.widget<Text>(value).style!;
      final bodyLarge = textTheme.bodyLarge!;
      // bodyLarge and bodyMedium differ in the test theme, so this pins the role.
      expect(bodyLarge.fontSize, isNot(textTheme.bodyMedium!.fontSize));
      expect(style.fontSize, bodyLarge.fontSize);
      expect(style.fontWeight, bodyLarge.fontWeight);
    });

    testWidgets('calls onCopied instead of the default toast', (tester) async {
      var copied = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullDetailsTableItem(
            label: 'Txid',
            displayValue: 'abc',
            copyValue: 'abc',
            onCopied: () => copied++,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.copy_outlined));
      await tester.pump();

      expect(copied, 1);
      expect(find.text('Copied to clipboard'), findsNothing);
    });

    testWidgets('hides the copy icon without a copy value', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullDetailsTableItem(label: 'Fee', displayValue: '210 sats'),
        ),
      );

      expect(find.byIcon(Icons.copy_outlined), findsNothing);
    });

    testWidgets('keeps the expandable child hidden by default', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullDetailsTableItem(
            label: 'Inputs',
            expandableChild: Text('details'),
          ),
        ),
      );

      expect(find.text('details'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('starts revealed when initiallyExpanded', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullDetailsTableItem(
            label: 'Inputs',
            expandableChild: Text('details'),
            initiallyExpanded: true,
          ),
        ),
      );

      expect(find.text('details'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump();

      expect(find.text('details'), findsNothing);
    });
  });
}
