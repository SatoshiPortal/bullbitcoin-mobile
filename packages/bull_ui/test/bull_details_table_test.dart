import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullDetailsTableItem', () {
    test('rejects onValueTap for custom value widgets', () {
      expect(
        () => BullDetailsTableItem(
          label: 'Fee',
          displayWidget: const Text('Fastest'),
          onValueTap: () {},
        ),
        throwsAssertionError,
      );
    });

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('renders the value in the medium-weight body role', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullDetailsTableItem(label: 'Fee', displayValue: '210 sats'),
        ),
      );

      final value = find.text('210 sats');
      final roles = tester.element(value).bullType;
      final style = tester.widget<Text>(value).style;
      expect(
        style,
        roles.body.copyWith(
          fontWeight: FontWeight.w500,
          color: testBullTheme.onSurface,
          decoration: TextDecoration.none,
        ),
      );
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

    testWidgets('exposes a 48 dp action when a fee value is editable', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullDetailsTableItem(
            label: 'Fee',
            displayValue: 'Fastest',
            onValueTap: () => taps++,
          ),
        ),
      );

      final action = find
          .ancestor(
            of: find.byIcon(Icons.chevron_right),
            matching: find.byType(GestureDetector),
          )
          .first;
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
      await tester.tap(action);
      expect(taps, 1);
      expect(find.byIcon(Icons.copy_outlined), findsNothing);
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
