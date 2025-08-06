class RecoverWalletError implements Exception {
  const RecoverWalletError(this.message);

  final String message;

  @override
  String toString() {
    return 'RecoverWalletError: $message';
  }
}

class TestFlowDefaultWalletAlreadyExistsError extends RecoverWalletError {
  const TestFlowDefaultWalletAlreadyExistsError()
    : super('This wallet already exists.');
}

class TestFlowWalletMismatchError extends RecoverWalletError {
  const TestFlowWalletMismatchError()
    : super(
        'A different default wallet already exists. You can only have one default wallet.',
      );
}

class BackupKeyDerivationFailedError extends RecoverWalletError {
  const BackupKeyDerivationFailedError()
    : super('Local backup key derivation failed.');
}

class BackupVaultCorruptedError extends RecoverWalletError {
  const BackupVaultCorruptedError()
    : super('Selected backup file is corrupted.');
}

class BackupVaultMissingDerivationPathError extends RecoverWalletError {
  const BackupVaultMissingDerivationPathError()
    : super('Backup file missing derivation path.');
}
