import 'package:bull_ui/app_theme.dart';
import 'package:bull_exchange/testing.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all four exchange actions invoke their matching callbacks', (
    tester,
  ) async {
    final selected = <ExchangeHomeAction>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
        home: Scaffold(body: ExchangeHomeActions(onAction: selected.add)),
      ),
    );
    expect(find.byType(BullQuickAction), findsNWidgets(4));
    for (var i = 0; i < ExchangeHomeAction.values.length; i++) {
      await tester.tap(find.byType(BullQuickAction).at(i));
    }
    expect(selected, ExchangeHomeAction.values);
  });
}
