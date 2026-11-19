import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart' show IconButton, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('inline Copy has a real 48 dp target and one edge copy', (
    tester,
  ) async {
    final writes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') writes.add(call.arguments);
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
            label: 'Receive address',
            text: 'public-full-address',
            copiedMessage: 'Copied',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final copy = find.byType(IconButton);
    final bounds = tester.getRect(copy);
    expect(bounds.width, greaterThanOrEqualTo(48));
    expect(bounds.height, greaterThanOrEqualTo(48));
    await tester.tapAt(bounds.centerLeft + const Offset(1, 0));
    await tester.pump();
    expect(writes, [
      {'text': 'public-full-address'},
    ]);
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
