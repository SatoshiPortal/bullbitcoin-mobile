import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';

/// Port for fetching parsed transactions by txid.
///
/// Used by [BuildTransactionUsecase] to resolve input values
/// by fetching parent transactions.
abstract class TransactionPort {
  /// Fetch a parsed [Transaction] by its txid.
  ///
  /// The returned transaction's outputs can be used to look up
  /// the value of an input that references this transaction.
  Future<Transaction> fetch({required String txid});
}
