import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'quick_action.dart';
import 'quick_actions_failure.dart';

/// Host adapter for an installation-wide string preference.
abstract interface class QuickActionsStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

abstract interface class QuickActionsRepository {
  @useResult
  Future<Result<QuickActionSelection?, QuickActionsFailure>> load();
  @useResult
  Future<Result<void, QuickActionsFailure>> save(
    QuickActionSelection selection,
  );
  @useResult
  Future<Result<void, QuickActionsFailure>> reset();
}
