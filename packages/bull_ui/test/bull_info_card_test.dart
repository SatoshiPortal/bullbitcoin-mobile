import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  testWidgets('a card action has a name and a 48 dp target', (tester) async {
    final semantics = tester.ensureSemantics();
    var opened = false;
    await tester.pumpWidget(
      wrapWithTheme(
        BullInfoCard(
          description: 'Try again',
          tagColor: testBullTheme.error,
          bgColor: testBullTheme.errorContainer,
          onTap: () => opened = true,
        ),
      ),
    );

    final action = find.byType(InkWell);
    expect(tester.getSize(action).shortestSide, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel(RegExp('Try again')), findsOneWidget);
    expect(find.bySemanticsLabel('Try again'), findsOneWidget);
    await tester.tap(action);
    expect(opened, isTrue);
    semantics.dispose();
  });

  testWidgets('announces the title and description once', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        wrapWithTheme(
          BullInfoCard(
            title: 'Payment instructions',
            description: 'Keep the reference',
            tagColor: testBullTheme.info,
            bgColor: testBullTheme.surfaceContainer,
            onTap: () {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Payment instructions\nKeep the reference'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Payment instructions')),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('an informational card has no tap target', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullInfoCard(
          title: '',
          description: 'Keep the payment reference',
          tagColor: testBullTheme.info,
          bgColor: testBullTheme.surfaceContainer,
        ),
      ),
    );

    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Keep the payment reference'), findsOneWidget);
  });
}
