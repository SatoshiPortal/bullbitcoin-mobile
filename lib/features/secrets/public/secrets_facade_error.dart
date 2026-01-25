import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';

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
      FailedToCreateNewMnemonicSecretError() => SecretCreationFailedError(
        applicationError,
      ),
      FailedToImportMnemonicSecretError() || FailedToImportSeedSecretError() =>
        SecretImportFailedError(applicationError),
      FailedToGetSecretError() => SecretNotFoundError(applicationError),
      FailedToRegisterSecretUsageError() => SecretUsageRegistrationFailedError(
        applicationError,
      ),
      FailedToDeregisterSecretUsageError() =>
        SecretUsageDeregistrationFailedError(applicationError),
      SecretInUseError() => SecretInUseFacadeError(applicationError),
      FailedToDeleteSecretError() => SecretDeletionFailedError(
        applicationError,
      ),
      BusinessRuleFailed() => SecretBusinessRuleViolationError(
        applicationError,
      ),
      _ => UnknownSecretsFacadeError(applicationError),
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

/// Thrown when registering seed usage fails (e.g., duplicate registration)
class SecretUsageRegistrationFailedError extends SecretsFacadeError {
  const SecretUsageRegistrationFailedError(Object? cause)
    : super('Failed to register seed usage.', cause: cause);
}

/// Thrown when deregistering seed usage fails
class SecretUsageDeregistrationFailedError extends SecretsFacadeError {
  const SecretUsageDeregistrationFailedError(Object? cause)
    : super('Failed to deregister seed usage.', cause: cause);
}

/// Thrown when attempting to delete a seed that is still in use
class SecretInUseFacadeError extends SecretsFacadeError {
  const SecretInUseFacadeError(Object? cause)
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

/// Thrown for any unexpected error
class UnknownSecretsFacadeError extends SecretsFacadeError {
  const UnknownSecretsFacadeError(Object? cause)
    : super('An unknown error occurred.', cause: cause);
}
