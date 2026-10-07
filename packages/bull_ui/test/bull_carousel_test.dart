import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

Widget _card(String label) =>
    SizedBox(height: 60, child: Center(child: Text(label)));

void main() {
  testWidgets('an empty carousel renders nothing', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const BullCarousel(children: [])));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BullCarousel)), Size.zero);
  });

  testWidgets('a single page shows no dots', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(BullCarousel(children: [_card('One')])),
    );

    expect(find.text('One'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('two pages show a dot each, and a swipe brings the second in', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(BullCarousel(children: [_card('One'), _card('Two')])),
    );

    expect(find.byType(AnimatedContainer), findsNWidgets(2));

    final screen = tester.getRect(find.byType(BullCarousel));
    expect(screen.overlaps(tester.getRect(find.text('One'))), isTrue);
    expect(screen.overlaps(tester.getRect(find.text('Two'))), isFalse);

    await tester.drag(find.byType(BullCarousel), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(screen.overlaps(tester.getRect(find.text('Two'))), isTrue);
    expect(screen.overlaps(tester.getRect(find.text('One'))), isFalse);
  });
}
