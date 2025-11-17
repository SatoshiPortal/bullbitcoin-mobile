import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class RecoverBullError extends BullError {
  RecoverBullError(super.message);
}

class SelectVaultError extends RecoverBullError {
  SelectVaultError(BuildContext context) : super(context.loc.recoverbullErrorSelectVault);
}

class PasswordIsNotSetError extends RecoverBullError {
  PasswordIsNotSetError(BuildContext context) : super(context.loc.recoverbullErrorPasswordNotSet);
}

class VaultIsNotSetError extends RecoverBullError {
  VaultIsNotSetError(BuildContext context) : super(context.loc.recoverbullErrorVaultNotSet);
}

class DecryptedVaultIsNotSetError extends RecoverBullError {
  DecryptedVaultIsNotSetError(BuildContext context) : super(context.loc.recoverbullErrorDecryptedVaultNotSet);
}

class KeyServerConnectionError extends RecoverBullError {
  KeyServerConnectionError(BuildContext context)
    : super(context.loc.recoverbullErrorConnectionFailed);
}

class InvalidFlowError extends RecoverBullError {
  InvalidFlowError(BuildContext context) : super(context.loc.recoverbullErrorInvalidFlow);
}

class VaultKeyNotStoredError extends RecoverBullError {
  VaultKeyNotStoredError(BuildContext context)
    : super(context.loc.recoverbullErrorVaultCreatedKeyNotStored);
}

class VaultCreationError extends RecoverBullError {
  VaultCreationError(BuildContext context)
    : super(context.loc.recoverbullErrorVaultCreationFailed);
}

class TorResponseFormatExceptionError extends RecoverBullError {
  TorResponseFormatExceptionError(BuildContext context)
    : super(context.loc.recoverbullErrorMissingBytes);
}

class VaultKeyFetchError extends RecoverBullError {
  VaultKeyFetchError(BuildContext context) : super(context.loc.recoverbullErrorFetchKeyFailed);
}

class VaultDecryptionError extends RecoverBullError {
  VaultDecryptionError(BuildContext context) : super(context.loc.recoverbullErrorDecryptFailed);
}

class VaultCheckStatusError extends RecoverBullError {
  VaultCheckStatusError(BuildContext context) : super(context.loc.recoverbullErrorCheckStatusFailed);
}

class VaultRecoveryError extends RecoverBullError {
  VaultRecoveryError(BuildContext context) : super(context.loc.recoverbullErrorRecoveryFailed);
}
