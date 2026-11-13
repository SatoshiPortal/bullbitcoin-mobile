import 'dart:convert';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStorage implements QuickActionsStorage {
  String? value;
  int writes = 0;
  bool failWrite = false;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw Exception('write failed');
    writes++;
    this.value = value;
  }

  @override
  Future<void> remove(String key) async => value = null;
}

void main() {
  const map = QuickAction.map;
  const transfer = QuickAction.transfer;
  const history = QuickAction.history;
  const buy = QuickAction.buy;
  const sell = QuickAction.sell;
  const pay = QuickAction.pay;
  const settings = QuickAction.settings;
  const available = {map, transfer, history, buy, sell, pay, settings};

  QuickActionsEditorLayout editor(QuickActionSelection selection) =>
      QuickActionsEditorLayout(selection: selection, available: available);

  group('divider layout', () {
    test('post-removal indices include the fixed separator', () {
      final layout = editor(
        QuickActionSelection([map, transfer], more: [buy, sell]),
      );
      expect(layout.items, [
        map,
        transfer,
        null,
        buy,
        sell,
        pay,
        settings,
        history,
      ]);
      final moved = layout.move(0, 1);
      expect(moved.actions, [transfer, map]);
      expect(moved.more, [buy, sell, pay, settings, history]);
      final toMore = layout.move(0, 2);
      expect(toMore.actions, [transfer]);
      expect(toMore.more, [map, buy, sell, pay, settings, history]);
      expect(layout.move(2, 0).actions, [map, transfer]);
      expect(layout.move(2, 0).more, [buy, sell]);
    });

    test(
      'inserting More at the end of full Home ejects the old third item',
      () {
        final layout = editor(
          QuickActionSelection([map, transfer, history], more: [buy, sell]),
        );
        final moved = layout.move(4, 3);
        expect(moved.actions, [map, transfer, buy]);
        expect(moved.more, [history, sell, pay, settings]);
      },
    );

    test('moves into empty Home and preserves More ordering', () {
      final layout = editor(QuickActionSelection([], more: [sell, buy, pay]));
      final moved = layout.move(2, 0);
      expect(moved.actions, [buy]);
      expect(moved.more, [sell, pay, settings, map, transfer, history]);
      final reordered = editor(moved).move(2, 4);
      expect(reordered.more, [pay, settings, sell, map, transfer, history]);
    });

    test('semantic moves match their drag destinations', () {
      final layout = editor(
        QuickActionSelection([map, transfer, history], more: [buy, sell]),
      );
      final home = layout.moveToHome(buy);
      final dragHome = layout.move(
        layout.items.indexOf(buy),
        layout.home.length,
      );
      expect(home.actions, dragHome.actions);
      expect(home.more, dragHome.more);
      final more = layout.moveToMore(transfer);
      final dragMore = layout.move(
        layout.items.indexOf(transfer),
        layout.home.length,
      );
      expect(more.actions, dragMore.actions);
      expect(more.more, dragMore.more);
    });

    test('unavailable actions stay in their respective partitions', () {
      final layout = QuickActionsEditorLayout(
        selection: QuickActionSelection(
          [map, QuickAction.exchange, transfer],
          more: [buy, QuickAction.support, sell],
        ),
        available: {map, transfer, buy, sell},
      );
      final moved = layout.move(layout.items.indexOf(buy), 0);
      expect(moved.actions, [buy, QuickAction.exchange, map, transfer]);
      expect(moved.more, [sell, QuickAction.support]);
    });

    test(
      'stored selections over three are displayed without a write',
      () async {
        final storage = FakeStorage()
          ..value = '{"home":["map","transfer","history","buy"],"more":[]}';
        final facade = createQuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        );
        final selection = await facade.load();
        expect(selection, isNotNull);
        expect(selection?.actions, [map, transfer, history, buy]);
        final layout = editor(selection as QuickActionSelection);
        expect(layout.home, [map, transfer, history]);
        expect(layout.more.first, buy);
        expect(storage.writes, 0);
        expect(
          storage.value,
          '{"home":["map","transfer","history","buy"],"more":[]}',
        );
        facade.close();
      },
    );

    test('Settings fallback is visual only', () async {
      final storage = FakeStorage()..value = '{"home":[],"more":[]}';
      final facade = createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      );
      final selection = await facade.load();
      expect(
        QuickActionsLayout.resolve(
          available: available,

          selection: selection,
        ).primary,
        [settings],
      );
      expect(editor(selection as QuickActionSelection).home, isEmpty);
      expect(selection.actions, isEmpty);
      expect(storage.value, '{"home":[],"more":[]}');
      expect(storage.writes, 0);
      facade.close();
    });
  });

  group('public storage facade', () {
    test(
      'reads and writes the object format without rewriting on load',
      () async {
        final storage = FakeStorage()
          ..value = '{"home":["map","buy"],"more":[]}';
        final facade = createQuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        );
        final loaded = await facade.load();
        expect(loaded?.actions, [map, buy]);
        expect(loaded?.more, isEmpty);
        expect(storage.writes, 0);
        expect(
          await facade.save(QuickActionSelection([transfer])),
          isA<Ok<void, QuickActionsFailure>>(),
        );
        expect(jsonDecode(storage.value as String), {
          'home': ['transfer'],
          'more': [],
        });
        expect(
          await facade.save(QuickActionSelection([map], more: [sell, buy])),
          isA<Ok<void, QuickActionsFailure>>(),
        );
        expect(jsonDecode(storage.value as String), {
          'home': ['map'],
          'more': ['sell', 'buy'],
        });
        facade.close();
        final reloadedFacade = createQuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        );
        final reloaded = await reloadedFacade.load();
        expect(reloaded?.actions, [map]);
        expect(reloaded?.more, [sell, buy]);
        expect(storage.writes, 2);
        reloadedFacade.close();
      },
    );

    test('invalid data warns and is never rewritten', () async {
      for (final raw in [
        '{"home":["map"],"more":["map"]}',
        '{"version":1,"home":[],"more":[]}',
        '{"version":3,"home":[],"more":[]}',
        '{"home":[]}',
        '{"home":[],"more":[1]}',
        '{"home":"map","more":[]}',
      ]) {
        final warnings = <String>[];
        final storage = FakeStorage()..value = raw;
        final facade = createQuickActionsCubit(
          storage: storage,
          warning: warnings.add,
          exchangeVisible: Stream.value(true),
        );
        expect(await facade.load(), isNull, reason: raw);
        expect(warnings, [
          'Could not read quick actions preference; using defaults',
        ], reason: raw);
        expect(storage.value, raw);
        expect(storage.writes, 0);
        facade.close();
      }
    });

    test('write failures are returned as typed failures', () async {
      final storage = FakeStorage()..failWrite = true;
      final facade = createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      );
      final result = await facade.save(QuickActionSelection([map]));
      expect(result, isA<Err<void, QuickActionsFailure>>());
      expect(
        (result as Err<void, QuickActionsFailure>).failure,
        isA<QuickActionsStorageFailure>(),
      );
      expect(storage.writes, 0);
      facade.close();
    });
  });
}
