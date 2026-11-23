import 'dart:async';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

class KeyedStorage implements QuickActionsStorage {
  final values = <String, String>{};
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<String?> read(String key) async {
    if (failRead) throw Exception('read failed');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw Exception('write failed');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('stays hidden until the host offers the exchange', () async {
    final offered = StreamController<bool>();
    final cubit = createExchangePromptCubit(
      storage: KeyedStorage(),
      warning: (_) {},
      offered: offered.stream,
    );
    addTearDown(cubit.close);
    addTearDown(offered.close);
    await settle();
    expect(cubit.state, isFalse);
    offered.add(true);
    await settle();
    expect(cubit.state, isTrue);
    offered.add(false);
    await settle();
    expect(cubit.state, isFalse);
  });

  test('stays hidden when offered but already dismissed in storage', () async {
    final storage = KeyedStorage();
    storage.values['quick_actions_exchange_prompt_dismissed'] = 'true';
    final cubit = createExchangePromptCubit(
      storage: storage,
      warning: (_) {},
      offered: Stream.value(true),
    );
    addTearDown(cubit.close);
    await settle();
    expect(cubit.state, isFalse);
  });

  test('dismiss hides immediately and persists for the next cubit', () async {
    final storage = KeyedStorage();
    final warnings = <String>[];
    final cubit = createExchangePromptCubit(
      storage: storage,
      warning: warnings.add,
      offered: Stream.value(true),
    );
    addTearDown(cubit.close);
    await settle();
    expect(cubit.state, isTrue);
    final dismissal = cubit.dismiss();
    expect(cubit.state, isFalse);
    await dismissal;
    expect(storage.values, {'quick_actions_exchange_prompt_dismissed': 'true'});
    final next = createExchangePromptCubit(
      storage: storage,
      warning: warnings.add,
      offered: Stream.value(true),
    );
    addTearDown(next.close);
    await settle();
    expect(next.state, isFalse);
    expect(warnings, isEmpty);
  });

  test('a failed dismissal write still hides the prompt and warns', () async {
    final storage = KeyedStorage()..failWrite = true;
    final warnings = <String>[];
    final cubit = createExchangePromptCubit(
      storage: storage,
      warning: warnings.add,
      offered: Stream.value(true),
    );
    addTearDown(cubit.close);
    await settle();
    expect(cubit.state, isTrue);
    await cubit.dismiss();
    expect(cubit.state, isFalse);
    expect(storage.values, isEmpty);
    expect(warnings, ['Could not save the exchange prompt dismissal']);
  });

  test('a failed read keeps the prompt hidden and warns', () async {
    final warnings = <String>[];
    final cubit = createExchangePromptCubit(
      storage: KeyedStorage()..failRead = true,
      warning: warnings.add,
      offered: Stream.value(true),
    );
    addTearDown(cubit.close);
    await settle();
    expect(cubit.state, isFalse);
    expect(warnings, [
      'Could not read the exchange prompt preference; hiding it',
    ]);
  });
}
