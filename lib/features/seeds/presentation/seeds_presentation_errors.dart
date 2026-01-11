import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';

sealed class SeedsPresentationError implements Exception {
  final String message;
  final Object? cause;
  const SeedsPresentationError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';

  /// Factory to convert application errors to presentation errors
  factory SeedsPresentationError.fromApplicationError(
    SeedsApplicationError applicationError,
  ) {
    return switch (applicationError) {
      FailedToLoadAllStoredSeedSecretsError() ||
      FailedToListUsedSeedsError() ||
      FailedToLoadLegacySeedsError() =>
        FailedToLoadSeedsViewError(applicationError),
      SeedInUseError() => CannotDeleteSeedInUseError(applicationError),
      FailedToDeleteSeedError() =>
        FailedToDeleteSeedPresentationError(applicationError),
      BusinessRuleFailed() => FailedToLoadSeedsViewError(applicationError),
      _ => UnknownSeedsPresentationError(applicationError),
    };
  }
}

class UnknownSeedsPresentationError extends SeedsPresentationError {
  const UnknownSeedsPresentationError(Object? cause)
    : super('An unknown error occurred in seeds presentation.', cause: cause);

  static UnknownSeedsPresentationError fromException(Object? exception) {
    return UnknownSeedsPresentationError(exception);
  }
}

/// Presented when loading the seeds view fails (loading seeds or seed usages)
class FailedToLoadSeedsViewError extends SeedsPresentationError {
  final SeedsApplicationError applicationError;

  FailedToLoadSeedsViewError(this.applicationError)
    : super('Failed to load seeds. Please try again.', cause: applicationError);
}

/// Presented when attempting to delete a seed that is currently in use
class CannotDeleteSeedInUseError extends SeedsPresentationError {
  final SeedsApplicationError applicationError;

  CannotDeleteSeedInUseError(this.applicationError)
    : super('Cannot delete seed because it is currently in use by one or more wallets.', cause: applicationError);
}

/// Presented when deletion of a seed fails
class FailedToDeleteSeedPresentationError extends SeedsPresentationError {
  final SeedsApplicationError applicationError;

  FailedToDeleteSeedPresentationError(this.applicationError)
    : super('Failed to delete seed. Please try again.', cause: applicationError);
}
