import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, String amountEquivalent) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PriceInput(
            currency: 'sats',
            amountEquivalent: amountEquivalent,
            availableCurrencies: const ['BTC', 'sats'],
            onCurrencyChanged: (_) {},
            amountController: controller,
            focusNode: null,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the equivalent as an approximation', (tester) async {
    await pump(tester, '7.00 USD');
    expect(find.text('~7.00 USD'), findsOneWidget);
  });

  // Without a price there is no equivalent: a lone "~" would read as a value.
  testWidgets('shows nothing when there is no equivalent', (tester) async {
    await pump(tester, '');
    expect(find.text('~'), findsNothing);
  });
}
