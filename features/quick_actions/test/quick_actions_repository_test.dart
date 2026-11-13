import 'package:bull_quick_actions/src/data/quick_actions_repository_impl.dart';
import 'package:bull_quick_actions/src/domain/quick_action.dart';
import 'package:bull_quick_actions/src/domain/quick_actions_failure.dart';
import 'package:bull_quick_actions/src/domain/usecases/load_quick_actions_usecase.dart';
import 'package:bull_quick_actions/src/domain/usecases/reset_quick_actions_usecase.dart';
import 'package:bull_quick_actions/src/domain/usecases/save_quick_actions_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'quick_actions_test.dart' show MemoryStorage;

void main() {
  test('use cases persist and remove an ordered selection', () async {
    final storage = MemoryStorage();
    final repository = QuickActionsRepositoryImpl(storage);
    final selection = QuickActionSelection(QuickAction.values.reversed);
    expect(
      await SaveQuickActionsUsecase(repository).execute(selection),
      isA<Ok<void, QuickActionsFailure>>(),
    );
    final result = await LoadQuickActionsUsecase(repository).execute();
    expect(result, isA<Ok<QuickActionSelection?, QuickActionsFailure>>());
    final loaded =
        (result as Ok<QuickActionSelection?, QuickActionsFailure>).value;
    expect(loaded?.actions, QuickAction.values.reversed.toList());
    expect(loaded?.actions, hasLength(10));
    expect(
      await ResetQuickActionsUsecase(repository).execute(),
      isA<Ok<void, QuickActionsFailure>>(),
    );
    expect(storage.value, isNull);
  });

  test(
    'malformed data becomes a typed failure without leaking its contents',
    () async {
      final storage = MemoryStorage()..value = 'private invalid value';
      final result = await LoadQuickActionsUsecase(
        QuickActionsRepositoryImpl(storage),
      ).execute();
      expect(result, isA<Err<QuickActionSelection?, QuickActionsFailure>>());
      final failure =
          (result as Err<QuickActionSelection?, QuickActionsFailure>).failure;
      expect(failure.logMessage, 'read');
      expect(storage.value, 'private invalid value');
    },
  );
}
