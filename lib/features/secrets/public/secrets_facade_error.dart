import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';

/// Public errors that the SecretsFacade can throw.
/// These are the only errors that external features should handle.
sealed class SecretsFacadeError implements Exception {
  final String message;
  final Object? cause;
  const SecretsFacadeError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';

  /// Factory to convert application errors to public facade errors
  factory SecretsFacadeError.fromApplicationError(
    SecretsApplicationError applicationError,
  ) {
    return switch (applicationError) {
      // Input validation errors - expose clearly to external callers
      InvalidMnemonicInputError(:final wordCount) => InvalidMnemonicError(
        wordCount,
      ),
      InvalidPassphraseInputError() => InvalidPassphraseError(),
      InvalidSeedInputError() => InvalidSeedBytesError(),
      // Operation errors
      FailedToCreateNewMnemonicSecretError() => SecretCreationFailedError(
        applicationError,
      ),
      FailedToImportMnemonicSecretError() || FailedToImportSeedSecretError() =>
        SecretImportFailedError(applicationError),
      FailedToGetSecretError() => SecretNotFoundError(applicationError),
      FailedToDeregisterSecretUsageError() =>
        SecretUsageDeregistrationFailedError(applicationError),
      SecretInUseError() => SecretInUseError(applicationError),
      FailedToDeleteSecretError() => SecretDeletionFailedError(
        applicationError,
      ),
      // Unexpected business rule violations
      BusinessRuleFailed() => SecretBusinessRuleViolationError(
        applicationError,
      ),
      _ => UnknownSecretsError(applicationError),
    };
  }
}

/// Thrown when creating a new seed fails
class SecretCreationFailedError extends SecretsFacadeError {
  const SecretCreationFailedError(Object? cause)
    : super('Failed to create new seed.', cause: cause);
}

/// Thrown when importing a seed fails (e.g., invalid mnemonic)
class SecretImportFailedError extends SecretsFacadeError {
  const SecretImportFailedError(Object? cause)
    : super(
        'Failed to import seed. The mnemonic may be invalid.',
        cause: cause,
      );
}

/// Thrown when a seed cannot be found
class SecretNotFoundError extends SecretsFacadeError {
  const SecretNotFoundError(Object? cause)
    : super('Secret not found.', cause: cause);
}

/// Thrown when deregistering seed usage fails
class SecretUsageDeregistrationFailedError extends SecretsFacadeError {
  const SecretUsageDeregistrationFailedError(Object? cause)
    : super('Failed to deregister seed usage.', cause: cause);
}

/// Thrown when attempting to delete a seed that is still in use
class SecretInUseError extends SecretsFacadeError {
  const SecretInUseError(Object? cause)
    : super('Cannot delete seed because it is currently in use.', cause: cause);
}

/// Thrown when deleting a seed fails
class SecretDeletionFailedError extends SecretsFacadeError {
  const SecretDeletionFailedError(Object? cause)
    : super('Failed to delete seed.', cause: cause);
}

/// Thrown when a business rule is violated
class SecretBusinessRuleViolationError extends SecretsFacadeError {
  const SecretBusinessRuleViolationError(Object? cause)
    : super('A seed business rule was violated.', cause: cause);
}

// Input validation errors - user-facing errors for invalid input

/// Thrown when an invalid mnemonic phrase is provided
class InvalidMnemonicError extends SecretsFacadeError {
  final int wordCount;

  const InvalidMnemonicError(this.wordCount)
    : super(
        'Invalid mnemonic phrase. Expected 12, 15, 18, 21, or 24 words, but got $wordCount words.',
      );
}

/// Thrown when a passphrase exceeds the maximum allowed length
class InvalidPassphraseError extends SecretsFacadeError {
  const InvalidPassphraseError()
    : super('Passphrase is too long. Maximum 256 characters allowed.');
}

/// Thrown when invalid seed bytes are provided
class InvalidSeedBytesError extends SecretsFacadeError {
  const InvalidSeedBytesError()
    : super(
        'Invalid seed format. Expected 16, 32, or 64 bytes (128, 256, or 512 bits).',
      );
}

/// Thrown for any unexpected error
class UnknownSecretsError extends SecretsFacadeError {
  const UnknownSecretsError(Object? cause)
    : super('An unknown error occurred.', cause: cause);
}
