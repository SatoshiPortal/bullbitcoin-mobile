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
