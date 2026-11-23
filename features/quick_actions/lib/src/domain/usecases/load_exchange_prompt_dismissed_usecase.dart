import 'package:primitives/primitives.dart';

import '../quick_actions_failure.dart';
import '../quick_actions_repository.dart';

final class LoadExchangePromptDismissedUsecase {
  const LoadExchangePromptDismissedUsecase(this._repository);
  final QuickActionsRepository _repository;

  Future<Result<bool, QuickActionsFailure>> execute() =>
      _repository.exchangePromptDismissed();
}
