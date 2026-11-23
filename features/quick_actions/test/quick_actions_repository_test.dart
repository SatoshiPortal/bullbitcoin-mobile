import 'package:bull_quick_actions/src/data/quick_actions_repository_impl.dart';
import 'package:bull_quick_actions/src/domain/quick_action.dart';
import 'package:bull_quick_actions/src/domain/quick_actions_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'exchange_prompt_cubit_test.dart' show KeyedStorage;
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
    expect(loaded?.actions, hasLength(9));
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

  test('exchange prompt is undismissed until dismissed', () async {
    final storage = KeyedStorage();
    final repository = QuickActionsRepositoryImpl(storage);
    final before = await repository.exchangePromptDismissed();
    expect(before, isA<Ok<bool, QuickActionsFailure>>());
    expect((before as Ok<bool, QuickActionsFailure>).value, isFalse);
    expect(
      await repository.dismissExchangePrompt(),
      isA<Ok<void, QuickActionsFailure>>(),
    );
    expect(storage.values.keys, [QuickActionsRepositoryImpl.exchangePromptKey]);
    expect(
      QuickActionsRepositoryImpl.exchangePromptKey,
      'quick_actions_exchange_prompt_dismissed',
    );
    final after = await repository.exchangePromptDismissed();
    expect(after, isA<Ok<bool, QuickActionsFailure>>());
    expect((after as Ok<bool, QuickActionsFailure>).value, isTrue);
  });

  test('exchange prompt dismissal is independent of the selection', () async {
    final storage = KeyedStorage();
    final repository = QuickActionsRepositoryImpl(storage);
    await repository.save(QuickActionSelection([QuickAction.map]));
    final undismissed = await repository.exchangePromptDismissed();
    expect((undismissed as Ok<bool, QuickActionsFailure>).value, isFalse);
    await repository.dismissExchangePrompt();
    await repository.reset();
    final dismissed = await repository.exchangePromptDismissed();
    expect((dismissed as Ok<bool, QuickActionsFailure>).value, isTrue);
  });

  test('exchange prompt storage exceptions become typed failures', () async {
    final repository = QuickActionsRepositoryImpl(
      KeyedStorage()
        ..failRead = true
        ..failWrite = true,
    );
    final read = await repository.exchangePromptDismissed();
    expect(read, isA<Err<bool, QuickActionsFailure>>());
    expect(
      (read as Err<bool, QuickActionsFailure>).failure,
      isA<QuickActionsStorageFailure>(),
    );
    final write = await repository.dismissExchangePrompt();
    expect(write, isA<Err<void, QuickActionsFailure>>());
    expect(
      (write as Err<void, QuickActionsFailure>).failure,
      isA<QuickActionsStorageFailure>(),
    );
  });
}
