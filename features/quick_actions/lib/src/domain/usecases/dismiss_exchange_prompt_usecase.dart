import 'package:primitives/primitives.dart';

import '../quick_actions_failure.dart';
import '../quick_actions_repository.dart';

final class DismissExchangePromptUsecase {
  const DismissExchangePromptUsecase(this._repository);
  final QuickActionsRepository _repository;

  Future<Result<void, QuickActionsFailure>> execute() =>
      _repository.dismissExchangePrompt();
}
