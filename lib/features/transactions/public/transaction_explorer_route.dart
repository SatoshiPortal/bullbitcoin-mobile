enum TransactionExplorerRoute {
  transactionExplorer('/transaction-explorer');

  const TransactionExplorerRoute(this.path);

  final String path;
}

final class TransactionExplorerArgs {
  final String txid;

  const TransactionExplorerArgs({required this.txid});
}
