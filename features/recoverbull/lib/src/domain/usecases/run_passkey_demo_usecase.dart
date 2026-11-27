import 'package:primitives/primitives.dart';

import '../repositories/passkey_demo_repository.dart';
import '../passkey_demo_operation.dart';

final class RunPasskeyDemoUsecase {
  final Future<bool> Function() _enabled;
  final PasskeyDemoRepository _repository;

  const RunPasskeyDemoUsecase(this._enabled, this._repository);

  Future<bool> isEnabled() => _enabled();
  PasskeyDemoOperation newOperation() => PasskeyDemoOperation(_enabled);

  Future<Result<String, PasskeyDemoFailure>> execute({
    String? accountId,
    PasskeyDemoOperation? operation,
  }) async {
    final current = operation ?? newOperation();
    if (!await current.isAllowed()) {
      return const Err(PasskeyDemoFailure.disabled);
    }
    final result = accountId == null
        ? await _repository.register(current)
        : await _repository.open(accountId, current);
    if (!await current.isAllowed()) {
      return const Err(PasskeyDemoFailure.disabled);
    }
    return result;
  }
}
