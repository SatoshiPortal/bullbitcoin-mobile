import 'package:silent/src/domain/repositories/sp_account_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_balance.dart';
import 'package:silent/src/domain/silent_failure.dart';

/// Reads the live session's balance for the send flow's amount ceiling check.
class GetSpBalanceUsecase {
  final SpAccountRepository _repository;

  GetSpBalanceUsecase({required this._repository});

  Result<SilentBalance, SilentFailure> execute() => _repository.balance();
}
