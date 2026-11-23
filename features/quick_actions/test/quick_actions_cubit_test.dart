import 'dart:async';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quick_actions_test.dart' show MemoryStorage;

void main() {
  test('initial load waits for the host visibility snapshot', () async {
    final visibility = StreamController<bool>();
    final cubit = createQuickActionsCubit(
      storage: MemoryStorage(),
      warning: (_) {},
      exchangeVisible: visibility.stream,
    );
    addTearDown(cubit.close);
    addTearDown(visibility.close);
    var loaded = false;
    final load = cubit.load().then((_) => loaded = true);
    await Future<void>.delayed(Duration.zero);
    expect(loaded, isFalse);
    visibility.add(true);
    await load;
    expect(cubit.state.available, contains(QuickAction.pay));
  });

  test('a null stored selection drafts the injected defaults', () async {
    const injected = [
      QuickAction.toggleAmounts,
      QuickAction.map,
      QuickAction.transfer,
    ];
    final cubit = createQuickActionsCubit(
      storage: MemoryStorage(),
      warning: (_) {},
      exchangeVisible: const Stream.empty(),
      defaults: injected,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.defaults, injected);
    expect(cubit.state.selection, isNull);
    expect(cubit.state.draft?.actions, injected);
  });

  test(
    'failed save restores the draft and keeps the confirmed selection',
    () async {
      final storage = MemoryStorage();
      final cubit = createQuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: const Stream.empty(),
      );
      await cubit.load();
      final initial = cubit.state.draft?.actions;
      expect(initial, isNotNull);
      storage.failWrite = true;
      await cubit.save(QuickActionSelection([QuickAction.pay]));
      expect(cubit.state.selection, isNull);
      expect(cubit.state.draft?.actions, initial);
      expect(cubit.state.saving, isFalse);
      await cubit.close();
    },
  );

  test('failed save during load still completes initialization', () async {
    final storage = DelayedReadStorage()..failWrite = true;
    final cubit = createQuickActionsCubit(
      storage: storage,
      warning: (_) {},
      exchangeVisible: const Stream.empty(),
    );
    final load = cubit.load();
    await cubit.save(QuickActionSelection([QuickAction.pay]));
    storage.firstRead.complete(null);
    await load;
    expect(cubit.state.initialized, isTrue);
    expect(cubit.state.draft?.actions, QuickActionsLayout.defaults);
    await cubit.close();
  });

  test('exchange visibility updates available actions', () async {
    final visibility = StreamController<bool>();
    final cubit = createQuickActionsCubit(
      storage: MemoryStorage(),
      warning: (_) {},
      exchangeVisible: visibility.stream,
    );
    visibility.add(false);
    await cubit.load();
    visibility.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.available, contains(QuickAction.exchange));
    visibility.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.available, isNot(contains(QuickAction.exchange)));
    await cubit.close();
    await visibility.close();
  });

  const exchangeOnly = {QuickAction.pay};
  const exchangeActions = {...exchangeOnly, QuickAction.exchange};

  Future<Set<QuickAction>> availableFor({
    required bool visible,
    Stream<bool>? entry,
  }) async {
    final cubit = entry == null
        ? createQuickActionsCubit(
            storage: MemoryStorage(),
            warning: (_) {},
            exchangeVisible: Stream.value(visible),
          )
        : createQuickActionsCubit(
            storage: MemoryStorage(),
            warning: (_) {},
            exchangeVisible: Stream.value(visible),
            exchangeEntry: entry,
          );
    addTearDown(cubit.close);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    return cubit.state.available;
  }

  test(
    'a hidden exchange without an entry hides every exchange action',
    () async {
      for (final entry in [null, Stream.value(false)]) {
        final available = await availableFor(visible: false, entry: entry);
        expect(available.intersection(exchangeActions), isEmpty);
        expect(
          available,
          QuickAction.values.toSet().difference(exchangeActions),
        );
      }
    },
  );

  test('an exchange entry alone only offers the exchange action', () async {
    final available = await availableFor(
      visible: false,
      entry: Stream.value(true),
    );
    expect(available, contains(QuickAction.exchange));
    expect(available.intersection(exchangeOnly), isEmpty);
    expect(available, QuickAction.values.toSet().difference(exchangeOnly));
  });

  test('a visible exchange offers every exchange action', () async {
    for (final entry in [null, Stream.value(false), Stream.value(true)]) {
      final available = await availableFor(visible: true, entry: entry);
      expect(available, QuickAction.values.toSet());
    }
  });

  test('withdrawing the exchange entry hides the exchange action', () async {
    final entry = StreamController<bool>();
    final cubit = createQuickActionsCubit(
      storage: MemoryStorage(),
      warning: (_) {},
      exchangeVisible: Stream.value(false),
      exchangeEntry: entry.stream,
    );
    addTearDown(cubit.close);
    addTearDown(entry.close);
    await cubit.load();
    entry.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.available, contains(QuickAction.exchange));
    entry.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.available, isNot(contains(QuickAction.exchange)));
  });
}

class DelayedReadStorage extends MemoryStorage {
  final firstRead = Completer<String?>();
  var reads = 0;

  @override
  Future<String?> read(String key) {
    reads++;
    return reads == 1 ? firstRead.future : super.read(key);
  }
}
