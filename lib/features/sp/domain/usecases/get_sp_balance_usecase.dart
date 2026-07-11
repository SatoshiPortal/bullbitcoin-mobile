import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';

/// Reads the live session's balance for the send flow's amount ceiling check.
/// Throws when no session is established or the scan holds the inner lock; the
/// caller treats a throw as "unknown" and defers to Rust prepare().
class GetSpBalanceUsecase {
  final SpAccountRepository _repository;

  GetSpBalanceUsecase({required this._repository});

  SpBalance execute() => _repository.balance();
}
