import 'package:bb_mobile/core/errors/bull_exception.dart';

class RecoverBullError extends BullError {
  RecoverBullError(super.message);
}

class SelectVaultError extends RecoverBullError {
  SelectVaultError() : super('Failed to select vault');
}

class PasswordIsNotSetError extends RecoverBullError {
  PasswordIsNotSetError() : super('Password is not set');
}

class VaultIsNotSetError extends RecoverBullError {
  VaultIsNotSetError() : super('Vault is not set');
}

class DecryptedVaultIsNotSetError extends RecoverBullError {
  DecryptedVaultIsNotSetError() : super('Decrypted vault is not set');
}

class KeyServerConnectionError extends RecoverBullError {
  KeyServerConnectionError()
    : super(
        'Failed to connect to the target key server. Please try again later!',
      );
}

class InvalidFlowError extends RecoverBullError {
  InvalidFlowError() : super('Invalid flow');
}

class VaultKeyNotStoredError extends RecoverBullError {
  VaultKeyNotStoredError()
    : super('Failed: Vault file created but key not stored in server');
}

class VaultCreationError extends RecoverBullError {
  VaultCreationError()
    : super('Vault creation failed, it can be the file or the key');
}

class TorResponseFormatExceptionError extends RecoverBullError {
  TorResponseFormatExceptionError()
    : super(
        'Missing bytes from the Tor response. Retry but if the issue persists, it is a known issue for some devices with Tor.',
      );
}

class VaultKeyFetchError extends RecoverBullError {
  VaultKeyFetchError() : super('Failed to fetch vault key from server');
}

class VaultDecryptionError extends RecoverBullError {
  VaultDecryptionError() : super('Failed to decrypt the vault');
}

class VaultCheckStatusError extends RecoverBullError {
  VaultCheckStatusError() : super('Failed to check the vault status');
}

class VaultRecoveryError extends RecoverBullError {
  VaultRecoveryError() : super('Failed to recover the vault');
}
