import 'package:bull_quick_actions/src/data/quick_actions_repository_impl.dart';
import 'package:bull_quick_actions/src/domain/quick_action.dart';
import 'package:bull_quick_actions/src/domain/quick_actions_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'quick_actions_test.dart' show MemoryStorage;

void main() {
  test('always writes the object format and rejects arrays', () async {
    final storage = MemoryStorage();
    final repository = QuickActionsRepositoryImpl(storage);
    await repository.save(QuickActionSelection([QuickAction.map]));
    expect(storage.value, '{"home":["map"],"more":[]}');
    storage.value = '["map"]';
    expect(
      await repository.load(),
      isA<Err<QuickActionSelection?, QuickActionsFailure>>(),
    );
  });

  test('persists and removes an ordered selection', () async {
    final storage = MemoryStorage();
    final repository = QuickActionsRepositoryImpl(storage);
    final selection = QuickActionSelection(QuickAction.values.reversed);
    expect(
      await repository.save(selection),
      isA<Ok<void, QuickActionsFailure>>(),
    );
    final result = await repository.load();
    expect(result, isA<Ok<QuickActionSelection?, QuickActionsFailure>>());
    final loaded =
        (result as Ok<QuickActionSelection?, QuickActionsFailure>).value;
    expect(loaded?.actions, QuickAction.values.reversed.toList());
    expect(loaded?.actions, hasLength(10));
    expect(await repository.reset(), isA<Ok<void, QuickActionsFailure>>());
    expect(storage.value, isNull);
  });

  test(
    'malformed data becomes a typed failure without leaking its contents',
    () async {
      final storage = MemoryStorage()..value = 'private invalid value';
      final result = await QuickActionsRepositoryImpl(storage).load();
      expect(result, isA<Err<QuickActionSelection?, QuickActionsFailure>>());
      final failure =
          (result as Err<QuickActionSelection?, QuickActionsFailure>).failure;
      expect(failure.logMessage, 'read');
      expect(storage.value, 'private invalid value');
    },
  );
}
