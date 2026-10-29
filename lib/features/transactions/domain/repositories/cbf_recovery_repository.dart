import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import '../transaction_failure.dart';

abstract interface class CbfRecoveryRepository {
  @useResult
  Future<Result<void, TransactionFailure>> retry(String walletId, String txid);
  @useResult
  Future<Result<void, TransactionFailure>> cancel(String walletId, String txid);
}
