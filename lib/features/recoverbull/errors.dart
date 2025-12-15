import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:flutter/material.dart';

abstract class RecoverBullError {
  String toTranslated(BuildContext context);
}

class UnexpectedError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorUnexpected;
  }
}

class SelectVaultError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorSelectVault;
  }
}

class PasswordIsNotSetError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorPasswordNotSet;
  }
}

class VaultIsNotSetError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorVaultNotSet;
  }
}

class DecryptedVaultIsNotSetError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorDecryptedVaultNotSet;
  }
}

class KeyServerConnectionError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorConnectionFailed;
  }
}

class InvalidFlowError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorInvalidFlow;
  }
}

class VaultKeyNotStoredError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorVaultCreatedKeyNotStored;
  }
}

class VaultCreationError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorVaultCreationFailed;
  }
}

class TorNotStartedError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullTorNotStarted;
  }
}

class TorResponseFormatExceptionError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorMissingBytes;
  }
}

class VaultKeyFetchError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorFetchKeyFailed;
  }
}

class VaultDecryptionError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorDecryptFailed;
  }
}

class VaultCheckStatusError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorCheckStatusFailed;
  }
}

class VaultRecoveryError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorRecoveryFailed;
  }
}

class VaultRateLimitedError extends RecoverBullError {
  final Duration retryIn;

  VaultRateLimitedError({required this.retryIn});

  @override
  String toTranslated(BuildContext context) {
    final seconds = retryIn.inSeconds;
    final minutes = retryIn.inMinutes;

    final String formattedTime;
    if (seconds < 60) {
      formattedTime = context.loc.durationSeconds(seconds.toString());
    } else {
      formattedTime =
          minutes == 1
              ? context.loc.durationMinute(minutes.toString())
              : context.loc.durationMinutes(minutes.toString());
    }

    return context.loc.recoverbullErrorRateLimited(formattedTime);
  }
}

class InvalidVaultCredentials extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorInvalidCredentials;
  }
}

class InvalidVaultFileFormatError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullSelectBackupFileNotValidError;
  }
}
