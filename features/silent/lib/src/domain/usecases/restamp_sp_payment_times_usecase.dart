import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/repositories/sp_account_repository.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

/// Stamps the confirmed SP payments still missing a block time, from the header
/// store the app already holds. Local only, so a pull-to-refresh can run it.
class RestampSpPaymentTimesUsecase {
  final SpAccountRepository _repository;

  RestampSpPaymentTimesUsecase({required this._repository});

  @useResult
  Result<void, SilentFailure> execute() =>
      _repository.restampMissingTimestamps();
}
