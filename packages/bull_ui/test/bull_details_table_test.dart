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

    testWidgets('names the copy action after its row and copies the value', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final messages = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          messages.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var copied = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullDetailsTableItem(
            label: 'Txid',
            displayValue: 'a1b2c3',
            copyValue: 'a1b2c3d4',
            onCopied: () => copied++,
          ),
        ),
      );

      final copy = find.bySemanticsLabel('Copy Txid');
      expect(copy, findsOneWidget);
      expect(
        tester.getSemantics(copy),
        matchesSemantics(
          label: 'Copy Txid',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      expect(tester.getSize(copy), const Size(48, 48));
      expect(find.byTooltip('Copy Txid'), findsOneWidget);

      await tester.tap(copy);
      await tester.pump();

      expect(copied, 1);
      final clipboardCalls = messages
          .where((call) => call.method == 'Clipboard.setData')
          .toList();
      expect(clipboardCalls, hasLength(1));
      expect(clipboardCalls.single.arguments, {'text': 'a1b2c3d4'});
      semantics.dispose();
    });

    testWidgets('publishes the disclosure state of the expand action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(
          const BullDetailsTableItem(
            label: 'Inputs',
            expandableChild: Text('details'),
          ),
        ),
      );

      final collapsed = find.bySemanticsLabel('Expand Inputs');
      expect(collapsed, findsOneWidget);
      expect(
        tester.getSemantics(collapsed),
        matchesSemantics(
          label: 'Expand Inputs',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );
      expect(tester.getSize(collapsed), const Size(48, 48));
      expect(find.byTooltip('Expand Inputs'), findsOneWidget);

      await tester.tap(collapsed);
      await tester.pump();

      expect(find.text('details'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Collapse Inputs')),
        matchesSemantics(
          label: 'Collapse Inputs',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );
      expect(find.byTooltip('Collapse Inputs'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('meets the tap target and label guidelines for its actions', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(
          const BullDetailsTable(
            items: [
              BullDetailsTableItem(
                label: 'Txid',
                displayValue: 'a1b2c3',
                copyValue: 'a1b2c3d4',
              ),
              BullDetailsTableItem(
                label: 'Address',
                displayValue: 'bc1q',
                copyValue: 'bc1qxyz',
                expandableChild: Text('script'),
              ),
            ],
          ),
        ),
      );

      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('names every row action after its own row in a table', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(
          const BullDetailsTable(
            items: [
              BullDetailsTableItem(
                label: 'Transaction ID',
                displayValue: 'a1b2',
                copyValue: 'a1b2c3',
              ),
              BullDetailsTableItem(
                label: 'Address',
                displayValue: 'bc1q',
                copyValue: 'bc1qxyz',
                expandableChild: Text('script'),
              ),
              BullDetailsTableItem(label: 'Fee', displayValue: '210 sats'),
            ],
          ),
        ),
      );

      expect(find.bySemanticsLabel('Copy Transaction ID'), findsOneWidget);
      expect(find.bySemanticsLabel('Copy Address'), findsOneWidget);
      expect(find.bySemanticsLabel('Expand Address'), findsOneWidget);
      // A row without a copy value or an expandable child owns no action, and
      // no action falls back to a bare, row-less name.
      expect(find.bySemanticsLabel('Copy Fee'), findsNothing);
      expect(find.bySemanticsLabel('Expand Fee'), findsNothing);
      expect(find.bySemanticsLabel('Copy'), findsNothing);
      expect(find.bySemanticsLabel('Expand'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Expand Address'));
      await tester.pump();

      expect(find.text('script'), findsOneWidget);
      expect(find.bySemanticsLabel('Collapse Address'), findsOneWidget);
      expect(find.bySemanticsLabel('Copy Address'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('names the actions in the app language', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('fr'),
              child: const BullDetailsTableItem(
                label: 'Frais',
                displayValue: '210 sats',
                copyValue: '210',
                expandableChild: Text('details'),
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Copier Frais'), findsOneWidget);
      expect(find.bySemanticsLabel('Développer Frais'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Développer Frais'));
      await tester.pump();

      expect(find.bySemanticsLabel('Réduire Frais'), findsOneWidget);
      semantics.dispose();
    });
  });
}
