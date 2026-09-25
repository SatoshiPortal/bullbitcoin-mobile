import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction_anchor.dart';
import 'package:bb_mobile/features/transactions/presentation/historical_value.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/historical_value_line.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  HistoricalValue? value, {
  bool showLabel = false,
  bool isIncoming = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HistoricalValueLine(
          value: value,
          currencyCode: 'USD',
          showLabel: showLabel,
          isIncoming: isIncoming,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders nothing at all when there is no value', (tester) async {
    // The whole unknown-rate behaviour: no placeholder, no explanation.
    await _pump(tester, null);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a single value always states its anchor', (tester) async {
    await _pump(
      tester,
      SingleValue(
        fiat: 2438.10,
        at: DateTime.utc(2026, 9, 3, 14, 32),
        reason: AnchorReason.sent,
      ),
    );
    expect(find.textContaining('2,438.10'), findsOneWidget);
    // A bare number would silently claim to be the moment the money moved.
    expect(find.textContaining('when you sent'), findsOneWidget);
  });

  testWidgets('a range reads as one string, never two rows', (tester) async {
    await _pump(
      tester,
      RangeValue(
        low: 972.40,
        high: 978.20,
        from: DateTime.utc(2026, 9, 1, 11, 58),
        to: DateTime.utc(2026, 9, 1, 12, 41),
      ),
    );
    final amounts = find.textContaining('≈');
    expect(amounts, findsOneWidget);
    final text = tester.widget<Text>(amounts).data!;
    expect(text, contains('972.40'));
    expect(text, contains('978.20'));
    expect(find.textContaining('sent between'), findsOneWidget);
  });

  testWidgets('the label appears only where it is asked for', (tester) async {
    final value = SingleValue(
      fiat: 146.29,
      at: DateTime.utc(2026, 9, 1, 9, 7),
      reason: AnchorReason.settled,
    );

    // The list has no room for a label.
    await _pump(tester, value);
    expect(find.text('Value when received'), findsNothing);

    // The details screen names the figure.
    await _pump(tester, value, showLabel: true);
    expect(find.text('Value when received'), findsOneWidget);
  });

  testWidgets('the label follows the direction', (tester) async {
    await _pump(
      tester,
      SingleValue(
        fiat: 100,
        at: DateTime.utc(2026, 9, 1, 9, 7),
        reason: AnchorReason.sent,
      ),
      showLabel: true,
      isIncoming: false,
    );
    expect(find.text('Value when sent'), findsOneWidget);
    expect(find.text('Value when received'), findsNothing);
  });

  testWidgets('a confirmed anchor says so rather than implying the send time', (
    tester,
  ) async {
    await _pump(
      tester,
      SingleValue(
        fiat: 731.55,
        at: DateTime.utc(2026, 9, 2, 3, 15),
        reason: AnchorReason.confirmed,
      ),
    );
    expect(find.textContaining('when it confirmed'), findsOneWidget);
  });
}
