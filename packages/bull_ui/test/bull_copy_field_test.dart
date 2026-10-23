import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullCopyField', () {
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
