import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

/// Reads the live session's balance for the send flow's amount ceiling check.
class GetSpBalanceUsecase {
  final SpAccountRepository _repository;

  GetSpBalanceUsecase({required this._repository});

  Result<SpBalance, SpFailure> execute() => _repository.balance();
}
