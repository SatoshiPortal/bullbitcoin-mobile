import 'dart:convert';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const all = QuickAction.values;
  const defaults = [
    QuickAction.map,
    QuickAction.transfer,
    QuickAction.history,
    QuickAction.settings,
  ];

  test('automatic layout uses host defaults and canonical complement', () {
    final layout = QuickActionsLayout.resolve(
      available: all.toSet(),
      defaults: defaults,
    );
    expect(layout.primary, defaults.take(3));
    expect(layout.more, [
      QuickAction.settings,
      QuickAction.buy,
      QuickAction.sell,
      QuickAction.pay,
      QuickAction.exchange,
      QuickAction.support,
      QuickAction.priceHistory,
    ]);
    final disabled = QuickActionsLayout.resolve(
      available: defaults.toSet(),
      defaults: defaults,
    );
    expect(disabled.primary, defaults);
    expect(disabled.more, isEmpty);
  });

  test('unavailable custom actions retain their position when restored', () {
    final selection = QuickActionSelection([
      QuickAction.buy,
      QuickAction.transfer,
      QuickAction.map,
    ]);
    final unavailable = QuickActionsLayout.resolve(
      available: defaults.toSet(),
      defaults: defaults,
      selection: selection,
    );
    expect(unavailable.primary, [QuickAction.transfer, QuickAction.map]);
    expect(unavailable.more, [QuickAction.history, QuickAction.settings]);
    final restored = QuickActionsLayout.resolve(
      available: all.toSet(),
      defaults: defaults,
      selection: selection,
    );
    expect(restored.primary, [
      QuickAction.buy,
      QuickAction.transfer,
      QuickAction.map,
    ]);
  });

  test(
    'reordered hidden favorites retain their new positions when available',
    () {
      final reordered = QuickActionSelection([
        QuickAction.transfer,
        QuickAction.sell,
        QuickAction.map,
        QuickAction.buy,
      ]);
      final hidden = QuickActionsLayout.resolve(
        available: defaults.toSet(),
        defaults: defaults,
        selection: reordered,
      );
      expect(hidden.primary, [QuickAction.transfer, QuickAction.map]);
      expect(reordered.actions, [
        QuickAction.transfer,
        QuickAction.sell,
        QuickAction.map,
        QuickAction.buy,
      ]);
      final restored = QuickActionsLayout.resolve(
        available: reordered.actions.toSet(),
        defaults: defaults,
        selection: reordered,
      );
      expect(restored.primary, reordered.actions);
      expect(restored.more, isEmpty);
    },
  );

  test('empty custom selection is distinct from automatic', () {
    final layout = QuickActionsLayout.resolve(
      available: defaults.toSet(),
      defaults: defaults,
      selection: QuickActionSelection([]),
    );
    expect(layout.primary, isEmpty);
    expect(layout.more, [
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
    ]);
  });

  test('more includes overflow favorites in canonical order', () {
    final selected = QuickActionSelection([
      QuickAction.exchange,
      QuickAction.buy,
      QuickAction.map,
      QuickAction.settings,
      QuickAction.sell,
    ]);
    final layout = QuickActionsLayout.resolve(
      available: selected.actions.toSet(),
      defaults: defaults,
      selection: selected,
    );
    expect(layout.primary, [
      QuickAction.exchange,
      QuickAction.buy,
      QuickAction.map,
    ]);
    expect(layout.more, [QuickAction.settings, QuickAction.sell]);
    expect(selected.actions, hasLength(5));
  });

  test('selection rejects duplicates while allowing more than four', () {
    expect(
      () => QuickActionSelection([QuickAction.buy, QuickAction.buy]),
      throwsArgumentError,
    );
    expect(QuickActionSelection(all.take(5)).actions, hasLength(5));
  });

  test(
    'preference ignores unknown IDs without rewriting and reset removes it',
    () async {
      final storage = MemoryStorage()
        ..value = jsonEncode(['buy', 'future', 'map']);
      final facade = QuickActionsFacade(storage: storage, warning: (_) {});
      expect((await facade.load())?.actions, [
        QuickAction.buy,
        QuickAction.map,
      ]);
      expect(storage.value, jsonEncode(['buy', 'future', 'map']));
      expect(await facade.reset(), isA<Ok<void, QuickActionsFailure>>());
      expect(storage.value, isNull);
    },
  );

  test('invalid preference falls back without rewriting and warns', () async {
    final storage = MemoryStorage()..value = '{';
    final warnings = <String>[];
    final facade = QuickActionsFacade(storage: storage, warning: warnings.add);
    expect(await facade.load(), isNull);
    expect(storage.value, '{');
    expect(warnings, hasLength(1));
  });

  test(
    'save failure is a value and leaves existing preference intact',
    () async {
      final storage = MemoryStorage()
        ..value = 'existing'
        ..failWrite = true;
      final facade = QuickActionsFacade(storage: storage, warning: (_) {});
      expect(
        await facade.save(QuickActionSelection([])),
        isA<Err<void, QuickActionsFailure>>(),
      );
      expect(storage.value, 'existing');
    },
  );
}

class MemoryStorage implements QuickActionsStorage {
  String? value;
  bool failWrite = false;

  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> remove(String key) async {
    value = null;
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw Exception('write failed');
    this.value = value;
  }
}
