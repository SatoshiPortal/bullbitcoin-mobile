import 'dart:async';
import 'dart:convert';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const available = {
    QuickAction.map,
    QuickAction.transfer,
    QuickAction.history,
    QuickAction.settings,
  };

  test('legacy selection projects three and retains its stored order', () {
    final selection = QuickActionSelection([
      QuickAction.buy,
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
    ]);
    final layout = QuickActionsLayout.resolve(
      available: available,
      defaults: const [],
      selection: selection,
    );
    expect(layout.primary, [
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
    ]);
    expect(layout.more, [QuickAction.settings]);
    expect(selection.actions, [
      QuickAction.buy,
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
    ]);
  });

  test(
    'editing home preserves unavailable actions and drops legacy surplus',
    () {
      final selection = QuickActionSelection([
        QuickAction.buy,
        QuickAction.map,
        QuickAction.sell,
        QuickAction.transfer,
        QuickAction.history,
        QuickAction.settings,
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
        QuickAction.buy,
        QuickAction.history,
        QuickAction.sell,
        QuickAction.map,
      ]);
      expect(
        QuickActionsLayout.resolve(
          available: available,
          defaults: const [],
          selection: edited,
        ).primary,
        [QuickAction.history, QuickAction.map],
      );
      expect(selection.actions, hasLength(6));
    },
  );

  test('unavailable moves cannot alter the preference', () {
    final selection = QuickActionSelection([QuickAction.map]);
    final editor = QuickActionsEditorLayout(
      selection: selection,
      available: available,
    );
    expect(editor.moveToHome(QuickAction.buy), same(selection));
    expect(editor.moveToMore(QuickAction.buy), same(selection));
  });

  test('empty selection uses settings only as an unrevised fallback', () {
    final selection = QuickActionSelection([]);
    final layout = QuickActionsLayout.resolve(
      available: available,
      defaults: const [],
      selection: selection,
    );
    expect(layout.primary, [QuickAction.settings]);
    expect(selection.actions, isEmpty);
  });

  test(
    'save and reset are serialized and notify in completion order',
    () async {
      final storage = DelayedStorage();
      final facade = QuickActionsFacade(storage: storage, warning: (_) {});
      final changes = <List<QuickAction>?>[];
      facade.addListener(() => changes.add(facade.selection?.actions));
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
      expect(changes, [
        [QuickAction.map],
        null,
      ]);
      expect(storage.value, isNull);
      facade.dispose();
    },
  );

  test('a failed write leaves state intact and the next write runs', () async {
    final storage = DelayedStorage();
    final facade = QuickActionsFacade(storage: storage, warning: (_) {});
    final first = facade.save(QuickActionSelection([QuickAction.map]));
    final second = facade.save(QuickActionSelection([QuickAction.transfer]));
    await Future<void>.delayed(Duration.zero);
    expect(storage.operations, ['write']);
    storage.completeNext(fail: true);
    expect(await first, isA<Err<void, QuickActionsFailure>>());
    expect(facade.initialized, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(storage.operations, ['write', 'write']);
    storage.completeNext();
    expect(await second, isA<Ok<void, QuickActionsFailure>>());
    expect(facade.selection?.actions, [QuickAction.transfer]);
    expect(jsonDecode(storage.value ?? ''), ['transfer']);
    facade.dispose();
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
