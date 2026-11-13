import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quick_actions_test.dart' show MemoryStorage;

void main() {
  testWidgets('More has the same interactive width as each favorite', (
    tester,
  ) async {
    final facade = QuickActionsCubit(
      storage: MemoryStorage(),
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [QuickActionsFallbackDelegate()],
        home: Scaffold(
          body: SizedBox(
            width: 334,
            child: QuickActionsRow(
              cubit: facade,
              onAction: (_) {},
              onCustomize: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder button(String label) => find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.button == true,
          ),
        )
        .first;
    final moreWidth = tester.getSize(button('More')).width;
    for (final label in ['Map', 'Transfer', 'History']) {
      expect(
        tester.getSize(button(label)).width,
        closeTo(moreWidth, .01),
        reason: 'More and favorites must have equal hit areas',
      );
    }
  });
}
