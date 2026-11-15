import 'package:bb_mobile/features/transactions/domain/entities/explored_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';

sealed class TransactionOwnership {
  const TransactionOwnership();
}

final class TransactionOwnershipLoading extends TransactionOwnership {
  const TransactionOwnershipLoading();
}

final class TransactionOwnershipKnown extends TransactionOwnership {
  final Wallet? owner;

  const TransactionOwnershipKnown(this.owner);
}

final class TransactionOwnershipUnavailable extends TransactionOwnership {
  const TransactionOwnershipUnavailable();
}

final class TransactionExplorerState {
  final String txid;
  final TransactionOwnership ownership;
  final bool isLoadingTransaction;
  final ExploredTransaction? transaction;
  final TransactionFailure? failure;

  const TransactionExplorerState({
    required this.txid,
    this.ownership = const TransactionOwnershipLoading(),
    this.isLoadingTransaction = false,
    this.transaction,
    this.failure,
  });

  TransactionExplorerState withOwnership(TransactionOwnership ownership) =>
      TransactionExplorerState(
        txid: txid,
        ownership: ownership,
        isLoadingTransaction: isLoadingTransaction,
        transaction: transaction,
        failure: failure,
      );

  TransactionExplorerState withTransactionLoading() => TransactionExplorerState(
    txid: txid,
    ownership: ownership,
    isLoadingTransaction: true,
    transaction: transaction,
  );

  TransactionExplorerState withTransaction(ExploredTransaction transaction) =>
      TransactionExplorerState(
        txid: txid,
        ownership: ownership,
        transaction: transaction,
      );

  TransactionExplorerState withFailure(TransactionFailure failure) =>
      TransactionExplorerState(
        txid: txid,
        ownership: ownership,
        failure: failure,
      );
}
