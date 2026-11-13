import 'package:primitives/primitives.dart';

import '../quick_actions_failure.dart';
import '../quick_actions_repository.dart';

final class ResetQuickActionsUsecase {
  const ResetQuickActionsUsecase(this._repository);
  final QuickActionsRepository _repository;

  Future<Result<void, QuickActionsFailure>> execute() => _repository.reset();
}
