import 'package:primitives/primitives.dart';
import '../repositories/cbf_recovery_repository.dart';
import '../transaction_failure.dart';

final class CancelUnrelayedTransactionUsecase {
  final CbfRecoveryRepository _repository;
  const CancelUnrelayedTransactionUsecase(this._repository);
  Future<Result<void, TransactionFailure>> execute(
    String walletId,
    String txid,
  ) => _repository.cancel(walletId, txid);
}
