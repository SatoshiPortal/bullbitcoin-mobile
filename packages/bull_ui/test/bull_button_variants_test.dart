import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('semantic variants use BullTheme colours', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Column(
          children: [
            BullButton.primary(label: 'Primary', onPressed: () {}),
            BullButton.secondary(label: 'Secondary', onPressed: () {}),
            BullButton.danger(label: 'Danger', onPressed: () {}),
          ],
        ),
      ),
    );

    final containers = tester.widgetList<Container>(find.byType(Container));
    expect(
      containers.any(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration! as BoxDecoration).color ==
                testBullTheme.primary,
      ),
      isTrue,
    );
    expect(
      containers.any(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration! as BoxDecoration).color ==
                testBullTheme.error,
      ),
      isTrue,
    );
    expect(
      containers.any(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration! as BoxDecoration).border != null,
      ),
      isTrue,
    );
  });

  testWidgets('semantic variants preserve disabled behavior', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullButton.primary(label: 'Disabled', onPressed: () {}, disabled: true),
      ),
    );

    expect(find.byType(AnimatedOpacity), findsOneWidget);
    expect(
      tester
          .widgetList<IgnorePointer>(find.byType(IgnorePointer))
          .any((pointer) => pointer.ignoring),
      isTrue,
    );
  });

  testWidgets('semantic variants support the compact size', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullButton.primary(
          label: 'Retry',
          onPressed: () {},
          size: BullButtonSize.small,
        ),
      ),
    );

    expect(
      tester.widget<BullButton>(find.byType(BullButton)).size,
      BullButtonSize.small,
    );
    expect(tester.getSize(find.byType(Container).last).width, 160);
  });
}
