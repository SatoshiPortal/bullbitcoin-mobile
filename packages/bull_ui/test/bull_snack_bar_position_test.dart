import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart' show Builder, ElevatedButton;
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Future<void> openToast(
    WidgetTester tester,
    void Function(BuildContext) show,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> letItExpire(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the toast in the top half of the screen', (tester) async {
    await openToast(
      tester,
      (context) => BullSnackBar.show(context, message: 'Saved'),
    );

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getCenter(find.text('Saved')).dy, lessThan(screenHeight / 2));

    await letItExpire(tester);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('showContent renders custom content', (tester) async {
    await openToast(
      tester,
      (context) => BullSnackBar.showContent(context, const Text('Custom')),
    );

    expect(find.text('Custom'), findsOneWidget);

    await letItExpire(tester);
  });
}
