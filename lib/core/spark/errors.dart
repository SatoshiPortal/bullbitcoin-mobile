class SparkError implements Exception {
  final String message;

  SparkError(this.message);

  @override
  String toString() => 'SparkError: $message';
}

class SparkWalletIsNotInitializedError extends SparkError {
  SparkWalletIsNotInitializedError()
      : super('Spark wallet is not initialized');
}

class SparkRequiresDevModeError extends SparkError {
  SparkRequiresDevModeError()
      : super('Spark requires dev mode to be enabled');
}
