import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customization_v2_test.dart' show localizations, openEditor;
import 'quick_actions_test.dart' show MemoryStorage;

void main() {
  for (final locale in ['en', 'fr']) {
    testWidgets('editor uses the short transfer label in $locale', (
      tester,
    ) async {
      await openEditor(
        tester,
        QuickActionsFacade(storage: MemoryStorage(), warning: (_) {}),
        locale: Locale(locale),
      );
      final l10n = localizations(tester);
      expect(find.text(l10n.transfer), findsNWidgets(2));
    });
  }

  testWidgets('semantic reorder replaces arrows and preserves draft and save', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final storage = MemoryStorage();
      await openEditor(
        tester,
        QuickActionsFacade(storage: storage, warning: (_) {}),
      );
      final l10n = localizations(tester);
      final handle = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == l10n.reorderAction(l10n.transfer),
      );
      expect(handle, findsOneWidget);
      final node = tester.getSemantics(handle);
      final actions = node.getSemanticsData().customSemanticsActionIds ?? [];
      final up = '${l10n.moveUp}: ${l10n.transfer}';
      final down = '${l10n.moveDown}: ${l10n.transfer}';
      expect(
        actions.map((id) => CustomSemanticsAction.getAction(id)?.label),
        containsAll([up, down]),
      );
      expect(find.byTooltip(up), findsNothing);
      expect(find.byTooltip(down), findsNothing);
      final owner = node.owner;
      expect(owner, isNotNull);
      owner?.performAction(
        node.id,
        SemanticsAction.customAction,
        actions.singleWhere(
          (id) => CustomSemanticsAction.getAction(id)?.label == up,
        ),
      );
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      await tester.tap(find.text(l10n.save));
      await tester.pumpAndSettle();
      expect(storage.value, '["transfer","map","history","settings"]');
    } finally {
      semantics.dispose();
    }
  });
}
