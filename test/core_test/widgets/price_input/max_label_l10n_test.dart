import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/price_input/balance_row.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Korean, because the key reads "MAX" in English and French alike.
Future<void> _pumpInKorean(WidgetTester tester, Widget child) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('the balance row names its max switch in the app language', (
    tester,
  ) async {
    await _pumpInKorean(
      tester,
      BalanceRow(balance: '1', currencyCode: 'sats', onMaxToggled: (_) {}),
    );

    expect(find.text('최대'), findsOneWidget);
  });

  testWidgets('a max amount reads in the app language', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pumpInKorean(
      tester,
      PriceInput(
        currency: 'sats',
        amountEquivalent: '',
        availableCurrencies: const ['sats'],
        onCurrencyChanged: null,
        amountController: controller,
        focusNode: null,
        isMax: true,
      ),
    );

    expect(find.text('최대'), findsOneWidget);
  });
}
