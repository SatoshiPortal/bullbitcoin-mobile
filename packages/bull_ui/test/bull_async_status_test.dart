import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart'
    show MediaQuery, MediaQueryData, TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'test_app.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets(
      'progress uses one shimmer and respects reduced motion $reducedMotion',
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
        expect(
          find.byType(BullShimmerLine),
          reducedMotion ? findsNothing : findsOneWidget,
        );
      },
    );
  }
}
