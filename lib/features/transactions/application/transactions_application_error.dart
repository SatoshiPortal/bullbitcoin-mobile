sealed class TransactionsApplicationError implements Exception {
  const TransactionsApplicationError();
}

class NoTransactionsToExportError extends TransactionsApplicationError {
  const NoTransactionsToExportError();
}
