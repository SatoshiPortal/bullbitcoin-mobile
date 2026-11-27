import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final withTitle in [true, false]) {
      testWidgets('the icon sits on the first line in a tall card '
          '(scale $scale, title $withTitle)', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SizedBox(
                height: 320,
                child: BullInfoCard(
                  title: withTitle ? 'Unable to connect to Boltz' : null,
                  description: 'Tap to configure',
                  tagColor: testBullTheme.error,
                  bgColor: testBullTheme.errorContainer,
                ),
              ),
            ),
          ),
        );
        final icon = tester.getCenter(find.byIcon(Icons.info_outline_rounded));
        final first = find.text(
          withTitle ? 'Unable to connect to Boltz' : 'Tap to configure',
        );
        final paragraph = tester.renderObject<RenderParagraph>(first);
        final firstLine = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 1),
            )
            .first
            .toRect()
            .shift(paragraph.localToGlobal(Offset.zero));
        expect(icon.dy, moreOrLessEquals(firstLine.center.dy, epsilon: 1.5));
      });
    }
  }

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
