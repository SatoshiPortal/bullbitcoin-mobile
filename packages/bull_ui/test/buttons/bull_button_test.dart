import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // App-wide notices are mounted in MaterialApp.builder, where no route provides a Material.
  testWidgets('works above the navigator, without a Material ancestor', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        builder: (context, child) => Stack(
          children: [
            ?child,
            Align(
              alignment: Alignment.bottomCenter,
              child: BullButton.small(
                label: 'Notice',
                onPressed: () => taps++,
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
              ),
            ),
          ],
        ),
        home: const SizedBox.shrink(),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Notice'));
    expect(taps, 1);
  });
}
