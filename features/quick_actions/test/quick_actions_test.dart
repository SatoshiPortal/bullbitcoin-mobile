import 'dart:convert';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const all = QuickAction.values;
  const defaults = [
    QuickAction.settings,
    QuickAction.history,
    QuickAction.transfer,
    QuickAction.toggleAmounts,
  ];

  test('automatic layout uses defaults and canonical complement', () {
    final layout = QuickActionsLayout.resolve(available: all.toSet());
    expect(layout.primary, defaults.take(3));
    expect(layout.more, [
      QuickAction.pay,
      QuickAction.exchange,
      QuickAction.toggleAmounts,
      QuickAction.support,
      QuickAction.priceHistory,
      QuickAction.map,
    ]);
    final disabled = QuickActionsLayout.resolve(available: defaults.toSet());
    expect(disabled.primary, defaults.take(3));
    expect(disabled.more, [QuickAction.toggleAmounts]);
  });

  test('injected defaults drive the row and its complement in More', () {
    const injected = [
      QuickAction.toggleAmounts,
      QuickAction.map,
      QuickAction.transfer,
    ];
    final layout = QuickActionsLayout.resolve(
      available: all.toSet(),
      defaults: injected,
    );
    expect(layout.primary, injected);
    expect(layout.more, contains(QuickAction.support));
    expect(layout.more, isNot(contains(QuickAction.toggleAmounts)));
    expect(layout.more, isNot(contains(QuickAction.map)));
    expect(layout.more, isNot(contains(QuickAction.transfer)));
  });

  test('the catalogue has nine actions and iOS shares the default row', () {
    expect(all, hasLength(9));
    expect(all.map((action) => action.id), isNot(contains('buy')));
    expect(all.map((action) => action.id), isNot(contains('sell')));
    expect(QuickActionsLayout.defaults, [
      QuickAction.settings,
      QuickAction.history,
      QuickAction.transfer,
    ]);
    expect(QuickActionsLayout.iosDefaults, QuickActionsLayout.defaults);
    expect(QuickActionsLayout.moreOrder.toSet(), all.toSet());
  });

  test('unavailable custom actions retain their position when restored', () {
    final selection = QuickActionSelection([
      QuickAction.pay,
      QuickAction.transfer,
      QuickAction.settings,
    ]);
    final unavailable = QuickActionsLayout.resolve(
      available: defaults.toSet(),

      selection: selection,
    );
    expect(unavailable.primary, [QuickAction.transfer, QuickAction.settings]);
    expect(unavailable.more, [QuickAction.toggleAmounts, QuickAction.history]);
    final restored = QuickActionsLayout.resolve(
      available: all.toSet(),

      selection: selection,
    );
    expect(restored.primary, [
      QuickAction.pay,
      QuickAction.transfer,
      QuickAction.settings,
    ]);
  });

  test(
    'reordered hidden favorites retain their new positions when available',
    () {
      final reordered = QuickActionSelection([
        QuickAction.transfer,
        QuickAction.exchange,
        QuickAction.settings,
        QuickAction.pay,
      ]);
      final hidden = QuickActionsLayout.resolve(
        available: defaults.toSet(),

        selection: reordered,
      );
      expect(hidden.primary, [QuickAction.transfer, QuickAction.settings]);
      expect(reordered.actions, [
        QuickAction.transfer,
        QuickAction.exchange,
        QuickAction.settings,
        QuickAction.pay,
      ]);
      final restored = QuickActionsLayout.resolve(
        available: reordered.actions.toSet(),

        selection: reordered,
      );
      expect(restored.primary, reordered.actions.take(3));
      expect(restored.more, [QuickAction.pay]);
    },
  );

  test('empty custom selection is distinct from automatic', () {
    final layout = QuickActionsLayout.resolve(
      available: defaults.toSet(),

      selection: QuickActionSelection([]),
    );
    expect(layout.primary, isEmpty);
    expect(layout.more, [
      QuickAction.toggleAmounts,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
    ]);
  });

  test('more includes overflow favorites in canonical order', () {
    final selected = QuickActionSelection([
      QuickAction.exchange,
      QuickAction.pay,
      QuickAction.map,
      QuickAction.toggleAmounts,
      QuickAction.history,
    ]);
    final layout = QuickActionsLayout.resolve(
      available: selected.actions.toSet(),

      selection: selected,
    );
    expect(layout.primary, [
      QuickAction.exchange,
      QuickAction.pay,
      QuickAction.map,
    ]);
    expect(layout.more, [QuickAction.toggleAmounts, QuickAction.history]);
    expect(selected.actions, hasLength(5));
  });

  test('selection rejects duplicates while allowing more than four', () {
    expect(
      () => QuickActionSelection([QuickAction.pay, QuickAction.pay]),
      throwsArgumentError,
    );
    expect(QuickActionSelection(all.take(5)).actions, hasLength(5));
  });

  test(
    'preference ignores unknown IDs without rewriting and reset removes it',
    () async {
      final storage = MemoryStorage()
        ..value = jsonEncode({
          'home': ['pay', 'future', 'map'],
          'more': [],
        });
      final facade = createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      );
      expect((await facade.load())?.actions, [
        QuickAction.pay,
        QuickAction.map,
      ]);
      expect(
        storage.value,
        jsonEncode({
          'home': ['pay', 'future', 'map'],
          'more': [],
        }),
      );
      expect(await facade.reset(), isA<Ok<void, QuickActionsFailure>>());
      expect(storage.value, isNull);
    },
  );

  test('retired buy and sell ids are ignored without rewriting', () async {
    const raw = '{"home":["map","buy","transfer"],"more":["sell"]}';
    final storage = MemoryStorage()..value = raw;
    final cubit = createQuickActionsCubit(
      storage: storage,
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    addTearDown(cubit.close);
    final selection = await cubit.load();
    expect(selection?.actions, [QuickAction.map, QuickAction.transfer]);
    expect(selection?.more, isEmpty);
    expect(storage.value, raw);
  });

  test(
    'a stored settings-only selection keeps Settings alone on Home',
    () async {
      final storage = MemoryStorage()
        ..value = '{"home":["settings"],"more":[]}';
      final cubit = createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(false),
      );
      addTearDown(cubit.close);
      final selection = await cubit.load();
      final layout = QuickActionsLayout.resolve(
        available: cubit.state.available,
        selection: selection,
      );
      expect(layout.primary, [QuickAction.settings]);
      expect(layout.more, contains(QuickAction.history));
      expect(storage.value, '{"home":["settings"],"more":[]}');
    },
  );

  test('invalid preference falls back without rewriting and warns', () async {
    final storage = MemoryStorage()..value = '{';
    final warnings = <String>[];
    final facade = createQuickActionsCubit(
      storage: storage,
      warning: warnings.add,
      exchangeVisible: Stream.value(true),
    );
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
      final facade = createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      );
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
