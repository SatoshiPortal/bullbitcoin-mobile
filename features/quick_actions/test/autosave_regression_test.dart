import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('removing a Home action persists before leaving the editor', (
    tester,
  ) async {
    final storage = _Storage();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [
          QuickActionsFallbackDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: QuickActionsCustomizationScreen(
          facade: QuickActionsFacade(storage: storage, warning: (_) {}),
          available: QuickAction.values.toSet(),
          defaults: const [
            QuickAction.map,
            QuickAction.transfer,
            QuickAction.history,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = QuickActionsLocalizations.of(
      tester.element(find.byType(QuickActionsCustomizationScreen)),
    );
    await tester.tap(find.byTooltip(l10n.removeAction(l10n.map)));
    await tester.pumpAndSettle();
    expect(storage.value, '["transfer","history"]');
    expect(find.byType(QuickActionsCustomizationScreen), findsOneWidget);
  });
}

class _Storage implements QuickActionsStorage {
  String? value = '["map","transfer","history"]';

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {
    this.value = value;
  }

  @override
  Future<void> remove(String key) async {
    value = null;
  }
}
