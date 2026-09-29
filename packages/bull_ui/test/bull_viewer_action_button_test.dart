import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullViewerActionButton', () {
    testWidgets('renders the label and fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          Center(
            child: BullViewerActionButton(
              icon: BullIcons.contentCopy,
              label: 'Copy',
              onTap: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));

      expect(taps, 1);
      expect(find.byIcon(BullIcons.contentCopy), findsOneWidget);
    });

    testWidgets('keeps a 44dp minimum touch target', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Center(
            child: BullViewerActionButton(
              icon: BullIcons.contentCopy,
              label: 'Copy',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(BullViewerActionButton)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });
}
