import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullCountdown', () {
    testWidgets('renders the remaining m:ss and ticks down', (tester) async {
      final until = DateTime.now().toUtc().add(const Duration(seconds: 90));
      await tester.pumpWidget(wrapWithTheme(BullCountdown(until: until)));

      // ~90s left -> "1:" prefix.
      expect(find.textContaining('1:'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      // Still counting, no exception thrown.
      expect(find.byType(BullCountdown), findsOneWidget);
    });

    testWidgets('shows 0:00 and keeps no timer when already past', (
      tester,
    ) async {
      final past = DateTime.now().toUtc().subtract(const Duration(seconds: 5));
      await tester.pumpWidget(wrapWithTheme(BullCountdown(until: past)));

      expect(find.text('0:00'), findsOneWidget);
      final state = tester.state<BullCountdownState>(
        find.byType(BullCountdown),
      );
      expect(state.timer, isNull);
    });

    testWidgets('restarts when handed a new deadline', (tester) async {
      final past = DateTime.now().toUtc().subtract(const Duration(seconds: 5));
      await tester.pumpWidget(wrapWithTheme(BullCountdown(until: past)));
      expect(find.text('0:00'), findsOneWidget);

      final until = DateTime.now().toUtc().add(const Duration(seconds: 90));
      await tester.pumpWidget(wrapWithTheme(BullCountdown(until: until)));
      expect(find.textContaining('1:'), findsOneWidget);
      final state = tester.state<BullCountdownState>(
        find.byType(BullCountdown),
      );
      expect(state.timer, isNotNull);
    });

    testWidgets('defaults to a medium-weight bodyMedium in primary', (
      tester,
    ) async {
      final until = DateTime.now().toUtc().add(const Duration(seconds: 90));
      await tester.pumpWidget(wrapWithTheme(BullCountdown(until: until)));

      final text = find.textContaining(':');
      final bodyMedium = Theme.of(tester.element(text)).textTheme.bodyMedium!;
      final style = tester.widget<Text>(text).style!;
      expect(style.fontSize, bodyMedium.fontSize);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.color, testBullTheme.primary);
    });
  });
}
