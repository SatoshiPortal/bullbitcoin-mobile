import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';

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
      FailedToLoadAllStoredSecretsError() ||
      FailedToListUsedSecretsError() ||
      FailedToLoadLegacySecretsError() => FailedToLoadSecretsViewError(
        applicationError,
      ),
      SecretInUseError() => CannotDeleteSecretInUseError(applicationError),
      FailedToDeleteSecretError() => FailedToDeleteSecretPresentationError(
        applicationError,
      ),
      BusinessRuleFailed() => FailedToLoadSecretsViewError(applicationError),
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
