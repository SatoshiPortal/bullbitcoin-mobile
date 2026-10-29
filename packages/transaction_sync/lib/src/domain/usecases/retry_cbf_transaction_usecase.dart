import 'package:primitives/primitives.dart';
import '../repositories/cbf_transaction_repository.dart';
import '../wallet_source_registration.dart';
import '../wallet_transaction_sync_failure.dart';

final class RetryCbfTransactionUsecase {
  final CbfTransactionRepository _repository;
  const RetryCbfTransactionUsecase(this._repository);
  Future<Result<String, WalletTransactionSyncFailure>> execute(
    WalletSourceRegistration registration,
    String txid,
  ) => _repository.retryCbfTransaction(registration, txid);
}
