import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Stamps the confirmed SP payments still missing a block time, from the header
/// store the app already holds. Local only, so a pull-to-refresh can run it.
class RestampSpPaymentTimesUsecase {
  final SpAccountRepository _repository;

  RestampSpPaymentTimesUsecase({required this._repository});

  @useResult
  Result<void, SpFailure> execute() => _repository.restampMissingTimestamps();
}
