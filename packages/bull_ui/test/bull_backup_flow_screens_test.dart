import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_app.dart';

void main() {
  testWidgets(
    'shared status shows an error, hides success extras, and invokes retry',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullStatusScreen(
            errorTitle: 'Failure',
            retryLabel: 'Retry',
            continueLabel: 'Continue',
            title: 'Success',
            isLoading: false,
            hasError: true,
            errorMessage: 'Unavailable',
            extras: const [Text('Success detail')],
            onTap: () => retries++,
          ),
        ),
      );
      expect(find.text('Failure'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('Success detail'), findsNothing);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    },
  );

  testWidgets('shared status invokes completion with the supplied label', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      wrapWithTheme(
        BullStatusScreen(
          errorTitle: 'Failure',
          retryLabel: 'Retry',
          continueLabel: 'Continue',
          title: 'Success',
          isLoading: false,
          extras: const [Text('Verified')],
          onTap: () => completed = true,
        ),
      ),
    );
    expect(find.text('Verified'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(completed, isTrue);
  });
}
