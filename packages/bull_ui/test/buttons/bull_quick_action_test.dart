import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tap and long press invoke their own callbacks', (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        Center(
          child: BullQuickAction(
            label: 'Transfer',
            icon: BullIcons.swapHoriz,
            onPressed: () => taps++,
            onLongPress: () => longPresses++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(BullQuickAction));
    await tester.longPress(find.byType(BullQuickAction));
    expect(taps, 1);
    expect(longPresses, 1);
    expect(
      tester.getSize(find.byType(BullQuickAction)).height,
      BullQuickAction.height,
    );
  });

  testWidgets('disabled action rejects tap and long press', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        Center(
          child: BullQuickAction(
            label: 'Transfer',
            icon: BullIcons.swapHoriz,
            onPressed: () => calls++,
            onLongPress: () => calls++,
            disabled: true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(BullQuickAction));
    await tester.longPress(find.byType(BullQuickAction));
    expect(calls, 0);
  });

  testWidgets(
    'long label remains one semantic name and ellipsizes at 200 percent',
    (tester) async {
      const label = 'Transaction history';
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrapWithTheme(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Center(
                child: SizedBox(
                  width: 78,
                  child: BullQuickAction(
                    label: label,
                    icon: BullIcons.history,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(BullQuickAction)).height,
          BullQuickAction.height,
        );
        expect(find.bySemanticsLabel(label), findsOneWidget);
        final text = tester.widget<Text>(find.text(label));
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, label);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('outlined actions render in dark themes', (tester) async {
    final dark = testBullTheme.copyWith(
      surface: const Color(0xFF171717),
      surfaceContainerHighest: const Color(0xFF303030),
      text: const Color(0xFFFFFFFF),
      border: const Color(0xFFAAAAAA),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [dark, BullShapes.standard],
        ),
        home: Scaffold(
          body: Center(
            child: BullQuickAction(
              label: 'More',
              icon: BullIcons.moreHoriz,
              onPressed: () {},
              outlined: true,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final circle = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(BullQuickAction),
            matching: find.byType(Container),
          ),
        )
        .firstWhere(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration as BoxDecoration).shape == BoxShape.circle,
        );
    expect((circle.decoration as BoxDecoration).border, isNotNull);
  });
}
