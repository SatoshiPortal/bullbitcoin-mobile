import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import '../wallet_source_registration.dart';
import '../wallet_transaction_sync_failure.dart';

abstract interface class CbfTransactionRepository {
  @useResult
  Future<Result<String, WalletTransactionSyncFailure>> retryCbfTransaction(
    WalletSourceRegistration registration,
    String txid,
  );
  @useResult
  Future<Result<void, WalletTransactionSyncFailure>> cancelCbfTransaction(
    WalletSourceRegistration registration,
    String txid,
  );
}
