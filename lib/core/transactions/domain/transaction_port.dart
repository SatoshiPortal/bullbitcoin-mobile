import 'package:bb_mobile/core/transactions/domain/domain_errors.dart';
import 'package:bb_mobile/core/transactions/domain/entities/transaction.dart';

/// Port for fetching parsed transactions by txid.
///
/// Implementations throw [TransactionPortError] on failure so consumers
/// can map the typed port-layer error into their own domain.
abstract class TransactionPort {
  /// Fetch a parsed [Transaction] by its txid.
  ///
  /// The returned transaction's outputs can be used to look up
  /// the value of an input that references this transaction.
  Future<Transaction> fetch({required String txid});
}
