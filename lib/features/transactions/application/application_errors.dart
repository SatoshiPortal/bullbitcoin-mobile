sealed class TransactionsApplicationError implements Exception {
  const TransactionsApplicationError();
}

class NoTransactionsToExportError extends TransactionsApplicationError {
  const NoTransactionsToExportError();
}

class InvalidDateRangeError extends TransactionsApplicationError {
  const InvalidDateRangeError();
}
