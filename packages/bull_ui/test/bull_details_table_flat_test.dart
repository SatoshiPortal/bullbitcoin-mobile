import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Divider, Icons;

import 'test_app.dart';

void main() {
  for (final flat in [false, true]) {
    testWidgets('table flat=$flat keeps rows, dividers and full copy', (
      tester,
    ) async {
      const txid =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final writes = <Object?>[];
      var copied = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') writes.add(call.arguments);
        return null;
      });
      try {
        await tester.pumpWidget(
          wrapWithTheme(
            BullDetailsTable(
              flat: flat,
              items: [
                const BullDetailsTableItem(
                  label: 'Fee',
                  displayValue: '210 sats',
                ),
                BullDetailsTableItem(
                  label: 'Txid',
                  displayValue: '01234567…89abcdef',
                  copyValue: txid,
                  onCopied: () => copied++,
                ),
              ],
            ),
          ),
        );
        final table = find.byType(BullDetailsTable);
        final frame = tester.widget<Container>(
          find.descendant(of: table, matching: find.byType(Container)).first,
        );
        expect(
          frame.padding,
          flat ? EdgeInsets.zero : const EdgeInsets.all(16),
        );
        if (flat) {
          expect(frame.decoration, isNull);
        } else {
          final decoration = frame.decoration as BoxDecoration;
          expect(decoration.border, isNotNull);
          expect(decoration.boxShadow, hasLength(1));
        }
        expect(
          find.descendant(of: table, matching: find.byType(Divider)),
          findsOneWidget,
        );
        expect(find.text('210 sats'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.copy_outlined));
        await tester.pump();
        expect(writes, [
          <String, Object?>{'text': txid},
        ]);
        expect(copied, 1);
        expect(find.text('Copied to clipboard'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      }
    });
  }
}
