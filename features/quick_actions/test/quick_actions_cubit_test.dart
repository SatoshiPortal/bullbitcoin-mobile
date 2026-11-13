import 'dart:async';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quick_actions_test.dart' show MemoryStorage;

void main() {
  test('initial load waits for the host visibility snapshot', () async {
    final visibility = StreamController<bool>();
    final cubit = QuickActionsCubit(
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
    expect(cubit.state.available, contains(QuickAction.buy));
  });

  test(
    'failed save restores the draft and keeps the confirmed selection',
    () async {
      final storage = MemoryStorage();
      final cubit = QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: const Stream.empty(),
      );
      await cubit.load();
      final initial = cubit.state.draft?.actions;
      expect(initial, isNotNull);
      storage.failWrite = true;
      await cubit.save(QuickActionSelection([QuickAction.buy]));
      expect(cubit.state.selection, isNull);
      expect(cubit.state.draft?.actions, initial);
      expect(cubit.state.saving, isFalse);
      await cubit.close();
    },
  );

  test('failed save during load still completes initialization', () async {
    final storage = DelayedReadStorage()..failWrite = true;
    final cubit = QuickActionsCubit(
      storage: storage,
      warning: (_) {},
      exchangeVisible: const Stream.empty(),
    );
    final load = cubit.load();
    await cubit.save(QuickActionSelection([QuickAction.buy]));
    storage.firstRead.complete(null);
    await load;
    expect(cubit.state.initialized, isTrue);
    expect(cubit.state.draft?.actions, QuickActionsLayout.defaults);
    await cubit.close();
  });

  test('exchange visibility updates available actions', () async {
    final visibility = StreamController<bool>();
    final cubit = QuickActionsCubit(
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
