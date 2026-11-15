import 'dart:async';
import 'dart:convert';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customization_test.dart' show openEditor, homeValue;
import 'divider_drag_test.dart' show largeView;
import 'quick_actions_test.dart' show MemoryStorage;

class _Storage extends MemoryStorage {
  int writes = 0;
  @override
  Future<void> write(String key, String value) async {
    writes++;
    await super.write(key, value);
  }
}

Future<_Storage> _open(WidgetTester tester) async {
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
  return storage;
}

Future<void> _drag(WidgetTester tester, Finder from, Finder to) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveBy(const Offset(0, -20));
  await tester.pump(const Duration(milliseconds: 30));
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
  await tester.pumpAndSettle();
}

Finder _tile(QuickAction action) => find.byKey(ValueKey(action.id));

List<String> _more(String? raw) => [
  for (final id in (jsonDecode(raw ?? '{}') as Map)['more'] as List) '$id',
];

void main() {
  testWidgets('dragging a Home tile onto another Home tile reorders Home', (
    tester,
  ) async {
    final storage = await _open(tester);
    await _drag(tester, _tile(QuickAction.map), _tile(QuickAction.history));
    expect(homeValue(storage.value), '["transfer","history","map"]');
    expect(storage.writes, 1);
  });

  testWidgets('a More tile dropped on a full Home ejects its last action', (
    tester,
  ) async {
    final storage = await _open(tester);
    await _drag(tester, _tile(QuickAction.sell), _tile(QuickAction.map));
    expect(homeValue(storage.value), '["sell","map","transfer"]');
    expect(_more(storage.value).first, 'history');
    expect(storage.writes, 1);
  });

  testWidgets('the More tile cannot be dragged but receives drops', (
    tester,
  ) async {
    final storage = await _open(tester);
    final moreTile = find.byKey(const ValueKey('quick-actions-more-tile'));
    expect(
      find.descendant(
        of: moreTile,
        matching: find.byType(LongPressDraggable<QuickAction>),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: moreTile,
        matching: find.byType(LongPressDraggable<QuickAction>),
      ),
      findsNothing,
    );
    await _drag(tester, moreTile, _tile(QuickAction.buy));
    expect(storage.writes, 0);
    expect(storage.value, isNull);
    await _drag(tester, _tile(QuickAction.transfer), moreTile);
    expect(homeValue(storage.value), '["map","history"]');
    expect(_more(storage.value).first, 'transfer');
    expect(storage.writes, 1);
  });

  testWidgets('a drop on an empty Home slot appends to Home', (tester) async {
    final storage = await _open(tester);
    await _drag(tester, _tile(QuickAction.history), _tile(QuickAction.buy));
    expect(homeValue(storage.value), '["map","transfer"]');
    final slot = tester
        .getRect(_tile(QuickAction.transfer))
        .translate(tester.getSize(_tile(QuickAction.transfer)).width + 8, 0);
    final gesture = await tester.startGesture(
      tester.getCenter(_tile(QuickAction.pay)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(slot.center);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(homeValue(storage.value), '["map","transfer","pay"]');
    expect(storage.writes, 2);
  });
}
