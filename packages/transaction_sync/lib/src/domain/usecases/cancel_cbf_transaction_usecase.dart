import 'package:primitives/primitives.dart';
import '../repositories/cbf_transaction_repository.dart';
import '../wallet_source_registration.dart';
import '../wallet_transaction_sync_failure.dart';

final class CancelCbfTransactionUsecase {
  final CbfTransactionRepository _repository;
  const CancelCbfTransactionUsecase(this._repository);
  Future<Result<void, WalletTransactionSyncFailure>> execute(
    WalletSourceRegistration registration,
    String txid,
  ) => _repository.cancelCbfTransaction(registration, txid);
}
