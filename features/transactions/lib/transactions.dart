import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'src/domain/entities/wallet_transaction.dart';
import 'src/domain/transaction_failure.dart';

export 'src/domain/entities/transaction.dart' show Transaction;
export 'src/domain/entities/transaction_input.dart';
export 'src/domain/entities/transaction_output.dart';
export 'src/domain/entities/wallet_transaction.dart';
export 'src/domain/transaction_failure.dart';
export 'src/ui/widgets/txs_syncing_indicator.dart' show TxsSyncingIndicator;
export 'src/ui/widgets/wallet_detail_txs_list.dart' show WalletDetailTxsList;
export 'src/ui/widgets/wallet_history_scope.dart' show WalletHistoryScope;

abstract interface class Transactions {
  @useResult
  Future<Result<WalletTransaction?, TransactionFailure>> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  });

  @useResult
  Future<Result<List<WalletTransaction>, TransactionFailure>>
  getWalletTransactions({required String walletId, bool sync = false});

  /// Emits visible transactions. An unavailable read leaves the observation active.
  Stream<WalletTransaction> watchWalletTransactionByAddress({
    required String walletId,
    required String toAddress,
  });

  /// Emits visible revisions for this transaction while the wallet is open.
  Stream<WalletTransaction> watchWalletTransactionByTxId({
    required String walletId,
    required String txId,
  });

  /// Best-effort labeling initiated by an explicit exchange completion.
  Future<void> labelCompletedExchangeOrders(List<Order> orders);
}
