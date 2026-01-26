import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';

sealed class SecretsPresentationError implements Exception {
  final String message;
  final Object? cause;
  const SecretsPresentationError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';

  /// Factory to convert application errors to presentation errors
  factory SecretsPresentationError.fromApplicationError(
    SecretsApplicationError applicationError,
  ) {
    return switch (applicationError) {
      // Input validation errors - provide specific user-friendly messages
      InvalidMnemonicInputError(:final wordCount) =>
        InvalidMnemonicPresentationError(wordCount),
      InvalidPassphraseInputError() => InvalidPassphrasePresentationError(),
      InvalidSeedInputError() => InvalidSeedBytesPresentationError(),
      // Operation-specific errors
      SecretInUseError() => CannotDeleteSecretInUseError(applicationError),
      FailedToDeleteSecretError() => FailedToDeleteSecretPresentationError(
        applicationError,
      ),
      // Group infrastructure/loading errors together
      FailedToLoadAllStoredSecretsError() ||
      FailedToListUsedSecretsError() ||
      FailedToLoadLegacySecretsError() => FailedToLoadSecretsViewError(
        applicationError,
      ),
      // Unexpected business rule violations (should not happen in normal flow)
      BusinessRuleFailed() => UnexpectedBusinessRuleError(applicationError),
      _ => UnknownSecretsPresentationError(applicationError),
    };
  }
}

class UnknownSecretsPresentationError extends SecretsPresentationError {
  const UnknownSecretsPresentationError(Object? cause)
    : super('An unknown error occurred in seeds presentation.', cause: cause);

  static UnknownSecretsPresentationError fromException(Object? exception) {
    return UnknownSecretsPresentationError(exception);
  }
}

/// Presented when loading the seeds view fails (loading seeds or seed usages)
class FailedToLoadSecretsViewError extends SecretsPresentationError {
  final SecretsApplicationError applicationError;

  FailedToLoadSecretsViewError(this.applicationError)
    : super('Failed to load seeds. Please try again.', cause: applicationError);
}

/// Presented when attempting to delete a seed that is currently in use
class CannotDeleteSecretInUseError extends SecretsPresentationError {
  final SecretsApplicationError applicationError;

  CannotDeleteSecretInUseError(this.applicationError)
    : super(
        'Cannot delete seed because it is currently in use by one or more wallets.',
        cause: applicationError,
      );
}

/// Presented when deletion of a seed fails
class FailedToDeleteSecretPresentationError extends SecretsPresentationError {
  final SecretsApplicationError applicationError;

  FailedToDeleteSecretPresentationError(this.applicationError)
    : super(
        'Failed to delete seed. Please try again.',
        cause: applicationError,
      );
}

// Input validation errors - user-friendly messages for invalid input

/// Presented when the user provides an invalid mnemonic phrase
class InvalidMnemonicPresentationError extends SecretsPresentationError {
  final int wordCount;

  InvalidMnemonicPresentationError(this.wordCount)
    : super(
        'Invalid recovery phrase: Expected 12, 15, 18, 21, or 24 words but got $wordCount words. '
        'Please check your input and try again.',
      );
}

/// Presented when the user provides a passphrase that is too long
class InvalidPassphrasePresentationError extends SecretsPresentationError {
  InvalidPassphrasePresentationError()
    : super(
        'Passphrase is too long. The maximum allowed length is 256 characters. '
        'Please shorten your passphrase and try again.',
      );
}

/// Presented when the user provides invalid seed bytes
class InvalidSeedBytesPresentationError extends SecretsPresentationError {
  InvalidSeedBytesPresentationError()
    : super(
        'Invalid seed format. The seed must be 16, 32, or 64 bytes (128, 256, or 512 bits). '
        'Please check your input and try again.',
      );
}

/// Presented when an unexpected business rule is violated (should rarely happen)
class UnexpectedBusinessRuleError extends SecretsPresentationError {
  final SecretsApplicationError applicationError;

  UnexpectedBusinessRuleError(this.applicationError)
    : super(
        'An unexpected validation error occurred. Please contact support if this persists.',
        cause: applicationError,
      );
}
