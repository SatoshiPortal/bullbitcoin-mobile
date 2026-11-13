import 'package:primitives/primitives.dart';

import '../quick_action.dart';
import '../quick_actions_failure.dart';
import '../quick_actions_repository.dart';

final class LoadQuickActionsUsecase {
  const LoadQuickActionsUsecase(this._repository);
  final QuickActionsRepository _repository;

  Future<Result<QuickActionSelection?, QuickActionsFailure>> execute() =>
      _repository.load();
}
