import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/disclosure_bottom_sheet.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders headings, callouts, and bullet lists', (tester) async {
    const body = '''
Introductory paragraph.

> Recommendation
> Keep only a small balance here.

## What is the Instant Payments Wallet?

Section paragraph.

### Example

- **Maximum balance:** 0.01 BTC
- Plain bullet
''';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: DisclosureBottomSheet(title: 'Disclosure', body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Introductory paragraph.'), findsOneWidget);
    expect(find.text('Recommendation'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    final sectionHeading = tester.widget<Text>(
      find.text('What is the Instant Payments Wallet?'),
    );
    expect(sectionHeading.style?.fontWeight, FontWeight.w600);

    final exampleHeading = tester.widget<Text>(find.text('Example'));
    expect(exampleHeading.style?.fontWeight, FontWeight.w600);

    expect(
      find.text('Maximum balance: 0.01 BTC', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Plain bullet'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
  });
}
