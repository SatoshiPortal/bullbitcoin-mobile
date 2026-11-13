import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customization_test.dart' show localizations, openEditor, homeValue;
import 'quick_actions_test.dart' show MemoryStorage;

void main() {
  for (final locale in ['en', 'fr']) {
    testWidgets('editor uses the short transfer label in $locale', (
      tester,
    ) async {
      await openEditor(
        tester,
        QuickActionsCubit(
          storage: MemoryStorage(),
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        ),
        locale: Locale(locale),
      );
      final l10n = localizations(tester);
      expect(find.text(l10n.transfer), findsNWidgets(2));
    });
  }

  testWidgets('semantic reorder replaces arrows and saves immediately', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final storage = MemoryStorage();
      await openEditor(
        tester,
        QuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        ),
      );
      final l10n = localizations(tester);
      final handle = find.descendant(
        of: find.byKey(const ValueKey('transfer')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == l10n.transfer,
        ),
      );
      expect(handle, findsOneWidget);
      final node = tester.getSemantics(handle);
      final actions = node.getSemanticsData().customSemanticsActionIds ?? [];
      final up = l10n.moveUp;
      final down = l10n.moveDown;
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
      expect(homeValue(storage.value), '["transfer","map","history"]');
    } finally {
      semantics.dispose();
    }
  });
}
