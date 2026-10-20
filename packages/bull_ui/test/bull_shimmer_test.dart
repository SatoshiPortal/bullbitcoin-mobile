import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  // A stretching parent hands its children a tight width. The shimmers must
  // still render at the width they were given, like the fee-row placeholder.
  Widget stretched(Widget child) => wrapWithTheme(
    SizedBox(
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child],
      ),
    ),
  );

  Size shimmerSize(WidgetTester tester) => tester.getSize(
    find.descendant(
      of: find.byType(Padding).first,
      matching: find.byType(Container),
    ),
  );

  testWidgets('BullShimmerLine keeps a fixed width in a stretching parent', (
    tester,
  ) async {
    await tester.pumpWidget(
      stretched(
        const BullShimmerLine(width: 160, height: 12, padding: EdgeInsets.zero),
      ),
    );

    expect(shimmerSize(tester), const Size(160, 12));
  });

  testWidgets('BullShimmerLine fills the width by default', (tester) async {
    await tester.pumpWidget(
      stretched(const BullShimmerLine(padding: EdgeInsets.zero)),
    );

    expect(shimmerSize(tester).width, 400);
  });

  testWidgets('BullShimmerBox keeps a fixed width in a stretching parent', (
    tester,
  ) async {
    await tester.pumpWidget(
      stretched(
        const BullShimmerBox(height: 72, width: 72, padding: EdgeInsets.zero),
      ),
    );

    // The container reports its size including its 16px margin on each side.
    expect(shimmerSize(tester), const Size(72 + 32, 72 + 32));
  });
}
