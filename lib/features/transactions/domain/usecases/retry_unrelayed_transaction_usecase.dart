import 'package:primitives/primitives.dart';
import '../repositories/cbf_recovery_repository.dart';
import '../transaction_failure.dart';

final class RetryUnrelayedTransactionUsecase {
  final CbfRecoveryRepository _repository;
  const RetryUnrelayedTransactionUsecase(this._repository);
  Future<Result<void, TransactionFailure>> execute(
    String walletId,
    String txid,
  ) => _repository.retry(walletId, txid);
}
