import 'dart:async';
import 'dart:convert';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart' show BullIcon, BullQuickAction;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customization_test.dart'
    show openEditor, localizations, semanticMove, homeValue, clearNotice;
import 'quick_actions_test.dart' show MemoryStorage;

class _Storage extends MemoryStorage {
  int writes = 0;
  Completer<void>? pending;
  @override
  Future<void> write(String key, String value) async {
    writes++;
    await pending?.future;
    await super.write(key, value);
  }
}

void largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<TestGesture> holdLabel(WidgetTester tester, QuickAction action) async {
  final tile = tester.getRect(find.byKey(ValueKey(action.id)));
  final gesture = await tester.startGesture(tile.center);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 300));
  return gesture;
}

Future<void> dropAcrossDivider(
  WidgetTester tester,
  TestGesture gesture, {
  required bool home,
}) async {
  final target = find.byKey(ValueKey(home ? 'history' : 'buy'));
  // These tiles lie immediately above/below the fixed separator.
  await gesture.moveTo(tester.getRect(target).center);
  await tester.pump(const Duration(milliseconds: 350));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'tile long press gives haptic and a lifted tile, then drops into More',
    (tester) async {
      largeView(tester);
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final storage = _Storage();
      await openEditor(
        tester,
        createQuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        ),
      );
      final gesture = await holdLabel(tester, QuickAction.history);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      expect(
        find.byKey(const ValueKey('quick-action-drag-feedback')),
        findsOneWidget,
      );
      expect(storage.writes, 0);
      await dropAcrossDivider(tester, gesture, home: false);
      expect(homeValue(storage.value), '["map","transfer"]');
      expect(
        ((jsonDecode(storage.value ?? '{}') as Map)['more'] as List).first,
        'history',
      );
      expect(storage.writes, 1);
    },
  );

  testWidgets('dropping a More tile on a full Home ejects the old third', (
    tester,
  ) async {
    largeView(tester);
    final storage = _Storage();
    await openEditor(
      tester,
      createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    final gesture = await holdLabel(tester, QuickAction.buy);
    await dropAcrossDivider(tester, gesture, home: true);
    expect(homeValue(storage.value), '["map","transfer","buy"]');
    expect(
      ((jsonDecode(storage.value ?? '{}') as Map)['more'] as List).first,
      'history',
    );
    expect(storage.writes, 1);
  });

  testWidgets(
    'failed physical drop restores both partitions and reports saveFailed',
    (tester) async {
      largeView(tester);
      final storage = _Storage()..failWrite = true;
      final facade = createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      );
      await openEditor(tester, facade);
      final l10n = localizations(tester);
      try {
        final gesture = await holdLabel(tester, QuickAction.history);
        await dropAcrossDivider(tester, gesture, home: false);
        expect(storage.value, isNull);
        expect(facade.state.selection, isNull);
        expect(find.text(l10n.saveFailed), findsOneWidget);
        final preview = tester.widgetList<BullQuickAction>(
          find.byType(BullQuickAction),
        );
        expect(preview.take(4).map((w) => w.label), [
          l10n.map,
          l10n.transfer,
          l10n.history,
          l10n.more,
        ]);
      } finally {
        await clearNotice(tester);
      }
    },
  );

  testWidgets('grid changes before a pending write completes', (tester) async {
    largeView(tester);
    final gate = Completer<void>();
    final storage = _Storage()..pending = gate;
    await openEditor(
      tester,
      createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    final l10n = localizations(tester);
    await semanticMove(tester, QuickAction.history, l10n.moveToMore);
    expect(storage.value, isNull);
    final preview = tester.widgetList<BullQuickAction>(
      find.byType(BullQuickAction),
    );
    expect(preview.take(3).map((w) => w.label), [
      l10n.map,
      l10n.transfer,
      l10n.more,
    ]);
    gate.complete();
    await tester.pumpAndSettle();
    expect(homeValue(storage.value), '["map","transfer"]');
  });

  testWidgets('reset Undo restores explicit Home and More ordering', (
    tester,
  ) async {
    largeView(tester);
    final original = jsonEncode({
      'home': ['transfer'],
      'more': ['history', 'buy', 'map', 'toggleAmounts'],
    });
    final storage = _Storage()..value = original;
    await openEditor(
      tester,
      createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    final l10n = localizations(tester);
    try {
      await tester.tap(find.text(l10n.reset));
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      await tester.tap(find.text(l10n.undo));
      await tester.pumpAndSettle();
      expect(storage.value, original);
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets('separator has no drag target or named move actions', (
    tester,
  ) async {
    largeView(tester);
    final semantics = tester.ensureSemantics();
    final storage = _Storage();
    try {
      await openEditor(
        tester,
        createQuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        ),
      );
      final divider = find.byKey(const ValueKey('quick-actions-divider'));
      expect(
        find.ancestor(
          of: divider,
          matching: find.byType(LongPressDraggable<QuickAction>),
        ),
        findsNothing,
      );
      expect(
        tester
                .getSemantics(divider)
                .getSemanticsData()
                .customSemanticsActionIds ??
            [],
        isEmpty,
      );
      await tester.longPress(divider);
      await tester.pumpAndSettle();
      expect(storage.writes, 0);
      expect(storage.value, isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final locale in ['en', 'fr']) {
    testWidgets(
      'short visible names with full accessible names and icons in $locale',
      (tester) async {
        largeView(tester);
        final semantics = tester.ensureSemantics();
        try {
          await openEditor(
            tester,
            createQuickActionsCubit(
              storage: _Storage(),
              warning: (_) {},
              exchangeVisible: Stream.value(true),
            ),
            locale: Locale(locale),
          );
          final l10n = localizations(tester);
          final price = find.byKey(const ValueKey('priceHistory'));
          expect(
            find.descendant(of: price, matching: find.text(l10n.priceHistory)),
            findsOneWidget,
          );
          final node = tester.getSemantics(
            find
                .descendant(
                  of: price,
                  matching: find.byType(Semantics),
                  matchRoot: true,
                )
                .first,
          );
          expect(node.label, l10n.priceHistoryFull);
          expect(
            find.descendant(of: price, matching: find.byType(BullIcon)),
            findsOneWidget,
          );
        } finally {
          semantics.dispose();
        }
      },
    );
    testWidgets('accessible up and down cross the fixed separator in $locale', (
      tester,
    ) async {
      largeView(tester);
      final storage = _Storage();
      await openEditor(
        tester,
        createQuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        ),
        locale: Locale(locale),
      );
      final l10n = localizations(tester);
      await semanticMove(tester, QuickAction.history, l10n.moveDown);
      expect(homeValue(storage.value), '["map","transfer"]');
      expect(
        ((jsonDecode(storage.value ?? '{}') as Map)['more'] as List).first,
        'history',
      );
      await semanticMove(tester, QuickAction.history, l10n.moveUp);
      expect(homeValue(storage.value), '["map","transfer","history"]');
      expect(storage.writes, 2);
    });
  }
}
