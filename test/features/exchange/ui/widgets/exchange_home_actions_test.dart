import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_actions.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all four exchange actions invoke their matching callbacks', (
    tester,
  ) async {
    final selected = <ExchangeHomeAction>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ExchangeHomeActions(onAction: selected.add)),
      ),
    );
    expect(find.byType(BullToolButton), findsNWidgets(4));
    for (var i = 0; i < ExchangeHomeAction.values.length; i++) {
      await tester.tap(find.byType(BullToolButton).at(i));
    }
    expect(selected, ExchangeHomeAction.values);
  });
}
