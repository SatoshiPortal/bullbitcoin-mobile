class RecoverWalletError implements Exception {
  const RecoverWalletError(this.message);

  final String message;

  @override
  String toString() {
    return 'RecoverWalletError: $message';
  }
}

class DefaultWalletAlreadyExistsError extends RecoverWalletError {
  const DefaultWalletAlreadyExistsError()
      : super(
          'A default wallet already exists. Please delete it before restoring from backup.',
        );
}
