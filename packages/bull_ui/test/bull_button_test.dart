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
}
