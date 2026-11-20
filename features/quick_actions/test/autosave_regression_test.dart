import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customization_test.dart' show semanticMove, homeValue;

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
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: QuickActionsCustomizationScreen(
          cubit: createQuickActionsCubit(
            storage: storage,
            warning: (_) {},
            exchangeVisible: Stream.value(true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = QuickActionsLocalizations.of(
      tester.element(find.byType(QuickActionsCustomizationScreen)),
    );
    await semanticMove(tester, QuickAction.map, l10n.moveToMore);
    await tester.pumpAndSettle();
    expect(homeValue(storage.value), '["transfer","support"]');
    expect(find.byType(QuickActionsCustomizationScreen), findsOneWidget);
  });
}

class _Storage implements QuickActionsStorage {
  String? value = '{"home":["map","transfer","support"],"more":[]}';

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
