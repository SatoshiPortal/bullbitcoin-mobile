import 'package:primitives/primitives.dart';

import '../quick_action.dart';
import '../quick_actions_failure.dart';
import '../quick_actions_repository.dart';

final class SaveQuickActionsUsecase {
  const SaveQuickActionsUsecase(this._repository);
  final QuickActionsRepository _repository;

  Future<Result<void, QuickActionsFailure>> execute(
    QuickActionSelection selection,
  ) => _repository.save(selection);
}
