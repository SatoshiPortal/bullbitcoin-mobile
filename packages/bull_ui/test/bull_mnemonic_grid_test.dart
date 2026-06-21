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
