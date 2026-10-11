import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows progress in the button and ignores taps while loading', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BullButton.big(
            label: 'Working',
            onPressed: () => taps++,
            bgColor: Colors.red,
            textColor: Colors.white,
            loading: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Working'), warnIfMissed: false);
    expect(taps, 0);
  });
  testWidgets('wrapped labels grow the button and remain tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: BullButton.big(
                  label: 'Recover the selected backup file',
                  maxLines: null,
                  onPressed: () => taps++,
                  bgColor: Colors.red,
                  textColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final text = find.text('Recover the selected backup file');
    expect(tester.getSize(find.byType(BullButton)).height, greaterThan(52));
    expect(
      tester
          .getRect(find.byType(BullButton))
          .contains(tester.getBottomRight(text)),
      isTrue,
    );
    await tester.tap(text);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
