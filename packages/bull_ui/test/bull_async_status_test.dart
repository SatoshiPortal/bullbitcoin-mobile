import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart'
    show MediaQuery, MediaQueryData, TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'test_app.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets(
      'progress uses the themed linear indicator and respects reduced motion $reducedMotion',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            MediaQuery(
              data: MediaQueryData(disableAnimations: reducedMotion),
              child: BullAsyncStatus.progress(
                label: 'Sending payment',
                color: testBullTheme.primary,
                textStyle: const TextStyle(),
              ),
            ),
          ),
        );
        expect(find.text('Sending payment'), findsOneWidget);
        expect(find.byType(BullShimmerLine), findsNothing);
        if (!reducedMotion) {
          final indicator = tester.widget<BullFadingLinearProgress>(
            find.byType(BullFadingLinearProgress),
          );
          expect(indicator.foregroundColor, testBullTheme.primary);
          expect(indicator.backgroundColor, testBullTheme.transparent);
        }
        expect(
          find.byType(BullFadingLinearProgress),
          reducedMotion ? findsNothing : findsOneWidget,
        );
      },
    );
  }
}
