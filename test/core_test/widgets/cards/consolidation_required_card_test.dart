import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/consolidation_required_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The card's tap guard must be scoped to the navigation, not one-shot:
/// tapping pushes the consolidation route ON TOP of the current screen, so
/// this card's State stays alive underneath and a permanent flag would leave
/// the card dead after the user pops back (the reported bug: tap → visit
/// consolidation → return → tapping again did nothing).
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required Future<void> Function()? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        home: Scaffold(
          body: ConsolidationRequiredCard(title: 'Consolidate', onTap: onTap),
        ),
      ),
    );
  }

  testWidgets('tap fires onTap', (tester) async {
    var taps = 0;
    await pumpCard(tester, onTap: () async => taps++);

    await tester.tap(find.byType(ConsolidationRequiredCard));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets(
    'a second tap while the navigation is still open (Future pending) is '
    'ignored — the double-tap guard',
    (tester) async {
      var taps = 0;
      // Completer stands in for context.pushNamed's Future: it only
      // completes when the pushed route is popped.
      final navigation = Completer<void>();
      await pumpCard(
        tester,
        onTap: () {
          taps++;
          return navigation.future;
        },
      );

      await tester.tap(find.byType(ConsolidationRequiredCard));
      await tester.pump();
      await tester.tap(find.byType(ConsolidationRequiredCard));
      await tester.pump();

      expect(taps, 1); // second tap swallowed while navigating

      navigation.complete(); // let the test end cleanly
      await tester.pumpAndSettle();
    },
  );

  testWidgets('the card re-enables itself once the navigation Future completes '
      '(user popped back) — tap, return, tap again works', (tester) async {
    var taps = 0;
    var navigation = Completer<void>();
    await pumpCard(
      tester,
      onTap: () {
        taps++;
        return navigation.future;
      },
    );

    // First tap: navigates.
    await tester.tap(find.byType(ConsolidationRequiredCard));
    await tester.pump();
    expect(taps, 1);

    // User pops back: the navigation Future completes.
    navigation.complete();
    await tester.pumpAndSettle();

    // Second tap must work again — this is the reported bug's regression
    // test (the old one-shot flag stayed set forever).
    navigation = Completer<void>();
    await tester.tap(find.byType(ConsolidationRequiredCard));
    await tester.pump();
    expect(taps, 2);

    navigation.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the guard re-enables even when the navigation Future throws', (
    tester,
  ) async {
    var taps = 0;
    var shouldThrow = true;
    await pumpCard(
      tester,
      onTap: () async {
        taps++;
        if (shouldThrow) throw Exception('router error');
      },
    );

    await tester.tap(find.byType(ConsolidationRequiredCard));
    await tester.pumpAndSettle();
    expect(taps, 1);
    // The error is reported through FlutterError (not silently swallowed,
    // not an unhandled async error)...
    expect(tester.takeException(), isA<Exception>());

    // ...and must not leave the guard stuck: the next tap works.
    shouldThrow = false;
    await tester.tap(find.byType(ConsolidationRequiredCard));
    await tester.pumpAndSettle();
    expect(taps, 2);
  });

  testWidgets('null onTap renders an inert card', (tester) async {
    await pumpCard(tester, onTap: null);

    await tester.tap(find.byType(ConsolidationRequiredCard));
    await tester.pumpAndSettle();

    expect(find.text('Consolidate'), findsOneWidget); // still renders fine
  });
}
