import 'package:bb_mobile/core/errors/bull_exception.dart';

class RecoverWalletError extends BullException {
  RecoverWalletError(super.message);
}

class TestFlowDefaultWalletAlreadyExistsError extends RecoverWalletError {
  TestFlowDefaultWalletAlreadyExistsError()
    : super('This wallet already exists.');
}

class TestFlowWalletMismatchError extends RecoverWalletError {
  TestFlowWalletMismatchError()
    : super(
        'A different default wallet already exists. You can only have one default wallet.',
      );
}

class BackupKeyDerivationFailedError extends RecoverWalletError {
  BackupKeyDerivationFailedError()
    : super('Local backup key derivation failed.');
}

class BackupVaultCorruptedError extends RecoverWalletError {
  BackupVaultCorruptedError() : super('Selected backup file is corrupted.');
}

class BackupVaultMissingDerivationPathError extends RecoverWalletError {
  BackupVaultMissingDerivationPathError()
    : super('Backup file missing derivation path.');
}
