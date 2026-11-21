import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart'
    show Icons, Scaffold, SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullCopyField', () {
    testWidgets('delegates sensitive copying to its owner', (tester) async {
      var copied = false;
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(
            body: BullCopyField(
              text: 'hidden',
              copiedMessage: 'Copied',
              onCopy: () => copied = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.copy_sharp));
      await tester.pump();
      expect(copied, isTrue);
      expect(
        calls.where((call) => call.method == 'Clipboard.setData'),
        isEmpty,
      );
      expect(find.text('Copied'), findsNothing);
    });
    testWidgets('copies the value and confirms it in a toast', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          const Scaffold(
            body: BullCopyField(
              text: 'shown',
              clipboardText: 'copied',
              copiedMessage: 'Copied',
            ),
          ),
        ),
      );
      expect(find.text('shown'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.copy_sharp));
      await tester.pump();

      final setData = calls.where((c) => c.method == 'Clipboard.setData');
      expect(setData, hasLength(1));
      expect(setData.single.arguments, {'text': 'copied'});
      expect(find.text('Copied'), findsOneWidget);

      // Let the toast's auto-dismiss timer run out before the tree goes.
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('names its copy button with the translated Copy by default', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(
          const Scaffold(
            body: BullCopyField(text: 'value', copiedMessage: 'Copied'),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(BullFieldAction)),
        matchesSemantics(
          label: 'Copy',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('names its copy button with a caller label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(
          const Scaffold(
            body: BullCopyField(
              text: 'value',
              copiedMessage: 'Copied',
              copyLabel: 'Copy key',
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(BullFieldAction)),
        matchesSemantics(
          label: 'Copy key',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('views the whole value and copies the exact payload', (
      tester,
    ) async {
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

      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrapWithTheme(
            const Scaffold(
              body: BullCopyField.withView(
                text: 'Full payment address',
                clipboardText: 'bitcoin:full-payment-address',
                viewLabel: 'View address',
                viewTitle: 'Address',
                copyLabel: 'Copy address',
                copiedMessage: 'Copied',
              ),
            ),
          ),
        );
        final view = find.bySemanticsLabel('View address');
        expect(view, findsOneWidget);
        expect(tester.getSize(view).shortestSide, greaterThanOrEqualTo(48));
        await tester.tap(view);
        await tester.pumpAndSettle();
        expect(find.byType(SelectableText), findsOneWidget);
        expect(
          tester.widget<SelectableText>(find.byType(SelectableText)).data,
          'Full payment address',
        );

        await tester.tap(find.byType(BullViewerActionButton).first);
        await tester.pumpAndSettle();
        final copy = messages.singleWhere(
          (call) => call.method == 'Clipboard.setData',
        );
        expect(copy.arguments, {'text': 'bitcoin:full-payment-address'});
        expect(find.byType(SelectableText), findsNothing);
        await tester.pump(const Duration(minutes: 1));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('hides the copy button when there is nothing to copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Scaffold(
            body: BullCopyField(text: '', copiedMessage: 'Copied'),
          ),
        ),
      );
      expect(find.byIcon(Icons.copy_sharp), findsNothing);
    });
  });
}
