import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/consolidation_required_card.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required String title,
    String? body,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ConsolidationRequiredCard(
            title: title,
            body: body,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  testWidgets('renders the given title', (tester) async {
    await pumpCard(tester, title: 'Consolidate the wallet');

    expect(find.text('Consolidate the wallet'), findsOneWidget);
  });

  testWidgets('renders the body when provided', (tester) async {
    await pumpCard(
      tester,
      title: 'Consolidate the wallet',
      body: 'Something went wrong',
    );

    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('renders no body text when body is null', (tester) async {
    await pumpCard(tester, title: 'Consolidate the wallet');

    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await pumpCard(
      tester,
      title: 'Consolidate the wallet',
      onTap: () => tapped = true,
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('does nothing when tapped with no onTap given', (tester) async {
    await pumpCard(tester, title: 'Consolidate the wallet');

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    // No exception thrown, no state to assert — this just proves a null
    // onTap doesn't crash the widget.
  });
}
