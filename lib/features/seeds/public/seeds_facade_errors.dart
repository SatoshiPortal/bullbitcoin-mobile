import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';

/// Public errors that the SeedsFacade can throw.
/// These are the only errors that external features should handle.
sealed class SeedsFacadeError implements Exception {
  final String message;
  final Object? cause;
  const SeedsFacadeError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';

  /// Factory to convert application errors to public facade errors
  factory SeedsFacadeError.fromApplicationError(
    SeedsApplicationError applicationError,
  ) {
    return switch (applicationError) {
      FailedToCreateNewSeedMnemonicError() =>
        SeedCreationFailedError(applicationError),
      FailedToImportSeedMnemonicError() || FailedToImportSeedBytesError() =>
        SeedImportFailedError(applicationError),
      FailedToGetSeedSecretError() => SeedNotFoundError(applicationError),
      FailedToRegisterSeedUsageError() =>
        SeedUsageRegistrationFailedError(applicationError),
      FailedToDeregisterSeedUsageError() =>
        SeedUsageDeregistrationFailedError(applicationError),
      SeedInUseError() => SeedInUseFacadeError(applicationError),
      FailedToDeleteSeedError() => SeedDeletionFailedError(applicationError),
      BusinessRuleFailed() => SeedBusinessRuleViolationError(applicationError),
      _ => UnknownSeedsFacadeError(applicationError),
    };
  }
}

/// Thrown when creating a new seed fails
class SeedCreationFailedError extends SeedsFacadeError {
  const SeedCreationFailedError(Object? cause)
    : super('Failed to create new seed.', cause: cause);
}

/// Thrown when importing a seed fails (e.g., invalid mnemonic)
class SeedImportFailedError extends SeedsFacadeError {
  const SeedImportFailedError(Object? cause)
    : super('Failed to import seed. The mnemonic may be invalid.', cause: cause);
}

/// Thrown when a seed cannot be found
class SeedNotFoundError extends SeedsFacadeError {
  const SeedNotFoundError(Object? cause)
    : super('Seed not found.', cause: cause);
}

/// Thrown when registering seed usage fails (e.g., duplicate registration)
class SeedUsageRegistrationFailedError extends SeedsFacadeError {
  const SeedUsageRegistrationFailedError(Object? cause)
    : super('Failed to register seed usage.', cause: cause);
}

/// Thrown when deregistering seed usage fails
class SeedUsageDeregistrationFailedError extends SeedsFacadeError {
  const SeedUsageDeregistrationFailedError(Object? cause)
    : super('Failed to deregister seed usage.', cause: cause);
}

/// Thrown when attempting to delete a seed that is still in use
class SeedInUseFacadeError extends SeedsFacadeError {
  const SeedInUseFacadeError(Object? cause)
    : super('Cannot delete seed because it is currently in use.', cause: cause);
}

/// Thrown when deleting a seed fails
class SeedDeletionFailedError extends SeedsFacadeError {
  const SeedDeletionFailedError(Object? cause)
    : super('Failed to delete seed.', cause: cause);
}

/// Thrown when a business rule is violated
class SeedBusinessRuleViolationError extends SeedsFacadeError {
  const SeedBusinessRuleViolationError(Object? cause)
    : super('A seed business rule was violated.', cause: cause);
}

/// Thrown for any unexpected error
class UnknownSeedsFacadeError extends SeedsFacadeError {
  const UnknownSeedsFacadeError(Object? cause)
    : super('An unknown error occurred.', cause: cause);
}
