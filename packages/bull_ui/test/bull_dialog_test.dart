import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Size;

import 'test_app.dart';

void main() {
  testWidgets('centered content scrolls when it exceeds the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithTheme(
        const BullDialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Title'),
              SizedBox(height: 350),
              Text('End of content'),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    final end = find.text('End of content').hitTestable();
    expect(end, findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(end, findsOneWidget);
  });
}
