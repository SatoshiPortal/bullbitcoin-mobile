import 'dart:async';
import 'dart:convert';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const available = {
    QuickAction.map,
    QuickAction.transfer,
    QuickAction.support,
    QuickAction.toggleAmounts,
  };

  test('stored selection projects three and retains its stored order', () {
    final selection = QuickActionSelection([
      QuickAction.pay,
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.support,
      QuickAction.toggleAmounts,
    ]);
    final layout = QuickActionsLayout.resolve(
      available: available,

      selection: selection,
    );
    expect(layout.primary, [
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.support,
    ]);
    expect(layout.more, [QuickAction.toggleAmounts]);
    expect(selection.actions, [
      QuickAction.pay,
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.support,
      QuickAction.toggleAmounts,
    ]);
  });

  test('editing home preserves unavailable actions and drops surplus', () {
    final selection = QuickActionSelection([
      QuickAction.pay,
      QuickAction.map,
      QuickAction.exchange,
      QuickAction.transfer,
      QuickAction.support,
      QuickAction.toggleAmounts,
    ]);
    final demoted = QuickActionsEditorLayout(
      selection: selection,
      available: available,
    ).moveToMore(QuickAction.transfer);
    final edited = QuickActionsEditorLayout(
      selection: demoted,
      available: available,
    ).move(1, 0);
    expect(edited.actions, [
      QuickAction.pay,
      QuickAction.support,
      QuickAction.exchange,
      QuickAction.map,
    ]);
    expect(
      QuickActionsLayout.resolve(
        available: available,

        selection: edited,
      ).primary,
      [QuickAction.support, QuickAction.map],
    );
    expect(selection.actions, hasLength(6));
  });

  test('unavailable moves cannot alter the preference', () {
    final selection = QuickActionSelection([QuickAction.map]);
    final editor = QuickActionsEditorLayout(
      selection: selection,
      available: available,
    );
    expect(editor.moveToHome(QuickAction.pay), same(selection));
    expect(editor.moveToMore(QuickAction.pay), same(selection));
  });

  test('empty selection keeps Home empty without rewriting', () {
    final selection = QuickActionSelection([]);
    final layout = QuickActionsLayout.resolve(
      available: available,

      selection: selection,
    );
    expect(layout.primary, isEmpty);
    expect(selection.actions, isEmpty);
  });

  test(
    'save and reset are serialized and notify in completion order',
    () async {
      final storage = DelayedStorage();
      final facade = createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      );
      final changes = <List<QuickAction>?>[];
      facade.stream
          .where((state) => !state.saving && state.revision > 0)
          .listen((state) => changes.add(state.selection?.actions));
      final save = facade.save(QuickActionSelection([QuickAction.map]));
      final reset = facade.reset();
      await Future<void>.delayed(Duration.zero);
      expect(storage.operations, ['write']);
      storage.completeNext();
      expect(await save, isA<Ok<void, QuickActionsFailure>>());
      await Future<void>.delayed(Duration.zero);
      expect(storage.operations, ['write', 'remove']);
      storage.completeNext();
      expect(await reset, isA<Ok<void, QuickActionsFailure>>());
      await Future<void>.delayed(Duration.zero);
      expect(changes, [
        [QuickAction.map],
        null,
      ]);
      expect(storage.value, isNull);
      facade.close();
    },
  );

  test('a failed write leaves state intact and the next write runs', () async {
    final storage = DelayedStorage();
    final facade = createQuickActionsCubit(
      storage: storage,
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    final first = facade.save(QuickActionSelection([QuickAction.map]));
    final second = facade.save(QuickActionSelection([QuickAction.transfer]));
    await Future<void>.delayed(Duration.zero);
    expect(storage.operations, ['write']);
    storage.completeNext(fail: true);
    expect(await first, isA<Err<void, QuickActionsFailure>>());
    expect(facade.state.initialized, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(storage.operations, ['write', 'write']);
    storage.completeNext();
    expect(await second, isA<Ok<void, QuickActionsFailure>>());
    expect(facade.state.selection?.actions, [QuickAction.transfer]);
    expect(jsonDecode(storage.value ?? ''), {
      'home': ['transfer'],
      'more': [],
    });
    facade.close();
  });
}

class DelayedStorage implements QuickActionsStorage {
  String? value;
  final operations = <String>[];
  Completer<void>? pending;

  void completeNext({bool fail = false}) {
    final current = pending;
    if (current == null) throw StateError('No pending storage operation');
    pending = null;
    if (fail) {
      current.completeError(Exception('storage failed'));
    } else {
      current.complete();
    }
  }

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {
    operations.add('write');
    final operation = Completer<void>();
    pending = operation;
    await operation.future;
    this.value = value;
  }

  @override
  Future<void> remove(String key) async {
    operations.add('remove');
    final operation = Completer<void>();
    pending = operation;
    await operation.future;
    value = null;
  }
}
