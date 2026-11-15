import 'package:bb_mobile/features/transactions/domain/entities/explored_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Result;

abstract interface class TransactionExplorerRepository {
  @useResult
  Future<Result<ExploredTransaction, TransactionFailure>> fetch(String txid);
}
