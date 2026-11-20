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
  const support = QuickAction.support;
  const history = QuickAction.history;
  const settings = QuickAction.settings;
  const pay = QuickAction.pay;
  const amounts = QuickAction.toggleAmounts;
  const available = {map, transfer, support, history, settings, pay, amounts};

  QuickActionsEditorLayout editor(QuickActionSelection selection) =>
      QuickActionsEditorLayout(selection: selection, available: available);

  group('divider layout', () {
    test('post-removal indices include the fixed separator', () {
      final layout = editor(
        QuickActionSelection([map, transfer], more: [history, settings]),
      );
      expect(layout.items, [
        map,
        transfer,
        null,
        history,
        settings,
        pay,
        amounts,
        support,
      ]);
      final moved = layout.move(0, 1);
      expect(moved.actions, [transfer, map]);
      expect(moved.more, [history, settings, pay, amounts, support]);
      final toMore = layout.move(0, 2);
      expect(toMore.actions, [transfer]);
      expect(toMore.more, [map, history, settings, pay, amounts, support]);
      expect(layout.move(2, 0).actions, [map, transfer]);
      expect(layout.move(2, 0).more, [history, settings]);
    });

    test(
      'inserting More at the end of full Home ejects the old third item',
      () {
        final layout = editor(
          QuickActionSelection(
            [map, transfer, support],
            more: [history, settings],
          ),
        );
        final moved = layout.move(4, 3);
        expect(moved.actions, [map, transfer, history]);
        expect(moved.more, [support, settings, pay, amounts]);
      },
    );

    test('moves into empty Home and preserves More ordering', () {
      final layout = editor(
        QuickActionSelection([], more: [settings, history, pay]),
      );
      final moved = layout.move(2, 0);
      expect(moved.actions, [history]);
      expect(moved.more, [settings, pay, amounts, support, map, transfer]);
      final reordered = editor(moved).move(2, 4);
      expect(reordered.more, [pay, amounts, settings, support, map, transfer]);
    });

    test('semantic moves match their drag destinations', () {
      final layout = editor(
        QuickActionSelection(
          [map, transfer, support],
          more: [history, settings],
        ),
      );
      final home = layout.moveToHome(history);
      final dragHome = layout.move(
        layout.items.indexOf(history),
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

    test('a drop on a tile of the same zone takes that cell', () {
      final layout = editor(
        QuickActionSelection(
          [map, transfer, support],
          more: [history, settings],
        ),
      );
      expect(layout.dropOn(map, support).actions, [transfer, support, map]);
      expect(layout.dropOn(support, map).actions, [support, map, transfer]);
      final more = layout.dropOn(history, pay);
      expect(more.actions, [map, transfer, support]);
      expect(more.more, [settings, pay, history, amounts]);
      expect(layout.dropOn(map, map), same(layout.move(0, 0)));
    });

    test('a drop across zones lands before the target tile', () {
      final layout = editor(
        QuickActionSelection([map, transfer], more: [history, settings]),
      );
      final toMore = layout.dropOn(map, settings);
      expect(toMore.actions, [transfer]);
      expect(toMore.more, [history, map, settings, pay, amounts, support]);
      final toHome = layout.dropOn(settings, transfer);
      expect(toHome.actions, [map, settings, transfer]);
      expect(toHome.more, [history, pay, amounts, support]);
    });

    test('a drop on a full Home ejects its last action into More', () {
      final layout = editor(
        QuickActionSelection(
          [map, transfer, support],
          more: [history, settings],
        ),
      );
      final onTile = layout.dropOn(settings, map);
      expect(onTile.actions, [settings, map, transfer]);
      expect(onTile.more, [support, history, pay, amounts]);
      final atEnd = layout.dropAtEnd(settings, onHome: true);
      expect(atEnd.actions, layout.moveToHome(settings).actions);
      expect(atEnd.more, layout.moveToHome(settings).more);
    });

    test('a drop at the end of a zone appends to it', () {
      final layout = editor(
        QuickActionSelection([map, transfer], more: [history, settings]),
      );
      expect(layout.dropAtEnd(map, onHome: true).actions, [transfer, map]);
      expect(layout.dropAtEnd(history, onHome: true).actions, [
        map,
        transfer,
        history,
      ]);
      final toMore = layout.dropAtEnd(map, onHome: false);
      expect(toMore.actions, [transfer]);
      expect(toMore.more, [history, settings, pay, amounts, support, map]);
      expect(layout.dropAtEnd(transfer, onHome: true), same(layout.move(1, 1)));
    });

    test('unavailable actions stay in their respective partitions', () {
      final layout = QuickActionsEditorLayout(
        selection: QuickActionSelection(
          [map, QuickAction.exchange, transfer],
          more: [history, QuickAction.support, settings],
        ),
        available: {map, transfer, history, settings},
      );
      final moved = layout.move(layout.items.indexOf(history), 0);
      expect(moved.actions, [history, QuickAction.exchange, map, transfer]);
      expect(moved.more, [settings, QuickAction.support]);
    });

    test(
      'stored selections over three are displayed without a write',
      () async {
        final storage = FakeStorage()
          ..value = '{"home":["map","transfer","support","pay"],"more":[]}';
        final facade = createQuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        );
        final selection = await facade.load();
        expect(selection, isNotNull);
        expect(selection?.actions, [map, transfer, support, pay]);
        final layout = editor(selection as QuickActionSelection);
        expect(layout.home, [map, transfer, support]);
        expect(layout.more.first, pay);
        expect(storage.writes, 0);
        expect(
          storage.value,
          '{"home":["map","transfer","support","pay"],"more":[]}',
        );
        facade.close();
      },
    );

    test('empty Home stays empty without rewriting', () async {
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
        isEmpty,
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
          ..value = '{"home":["map","history"],"more":[]}';
        final facade = createQuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        );
        final loaded = await facade.load();
        expect(loaded?.actions, [map, history]);
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
          await facade.save(
            QuickActionSelection([map], more: [settings, history]),
          ),
          isA<Ok<void, QuickActionsFailure>>(),
        );
        expect(jsonDecode(storage.value as String), {
          'home': ['map'],
          'more': ['settings', 'history'],
        });
        facade.close();
        final reloadedFacade = createQuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        );
        final reloaded = await reloadedFacade.load();
        expect(reloaded?.actions, [map]);
        expect(reloaded?.more, [settings, history]);
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
