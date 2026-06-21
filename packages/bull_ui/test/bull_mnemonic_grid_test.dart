import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullMnemonicGrid', () {
    testWidgets('renders all words with 1-based numbering', (tester) async {
      const words = ['alpha', 'bravo', 'charlie', 'delta', 'echo'];
      await tester.pumpWidget(
        wrapWithTheme(const SingleChildScrollView(
          child: BullMnemonicGrid(words: words),
        )),
      );
      for (final w in words) {
        expect(find.text(w), findsOneWidget);
      }
      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byType(BullMnemonicWord), findsNWidgets(5));
    });

    testWidgets('renders 12 words with 2-digit numbering and no overflow',
        (tester) async {
      final words = [for (var i = 1; i <= 12; i++) 'word$i'];
      await tester.pumpWidget(
        wrapWithTheme(SingleChildScrollView(
          child: BullMnemonicGrid(words: words),
        )),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BullMnemonicWord), findsNWidgets(12));
      // Every index 1..12 is shown exactly once (covers the 2-digit path),
      // and numbering stops at the word count (no phantom 13th).
      for (var n = 1; n <= 12; n++) {
        expect(find.text('$n'), findsOneWidget);
      }
      expect(find.text('13'), findsNothing);
    });

    testWidgets('handles odd word counts without overflow', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const SingleChildScrollView(
          child: BullMnemonicGrid(words: ['one', 'two', 'three']),
        )),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BullMnemonicWord), findsNWidgets(3));
    });
  });

  group('BullSeedWarningCard', () {
    testWidgets('renders the supplied message', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullSeedWarningCard(message: 'Never share your phrase.'),
        ),
      );
      expect(find.text('Never share your phrase.'), findsOneWidget);
    });
  });
}
