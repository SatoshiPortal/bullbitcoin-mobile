import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';

sealed class SecretsApplicationError implements Exception {
  final String message;
  final Object? cause;
  const SecretsApplicationError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

/// Useful base when a domain rule bubbles up through a use case.
class BusinessRuleFailed extends SecretsApplicationError {
  final SecretsDomainError domainError;
  BusinessRuleFailed(this.domainError)
    : super(domainError.message, cause: domainError);
}

class SecretInUseError extends SecretsApplicationError {
  final String fingerprint;

  const SecretInUseError(this.fingerprint)
    : super('Cannot delete secret $fingerprint because it is in use.');
}

class FailedToDeleteSecretError extends SecretsApplicationError {
  final String fingerprint;

  const FailedToDeleteSecretError(this.fingerprint, Object? cause)
    : super('Failed to delete secret $fingerprint.', cause: cause);
}

class FailedToDeregisterSecretUsagesOfConsumerError
    extends SecretsApplicationError {
  final SecretConsumer? consumer;

  const FailedToDeregisterSecretUsagesOfConsumerError(
    this.consumer,
    Object? cause,
  ) : super(
        'Failed to deregister secret usages for consumer $consumer.',
        cause: cause,
      );
}

class FailedToRegisterSecretUsageError extends SecretsApplicationError {
  final String fingerprint;

  const FailedToRegisterSecretUsageError(this.fingerprint, Object? cause)
    : super('Failed to register usage for secret $fingerprint.', cause: cause);
}

class FailedToDeregisterSecretUsageError extends SecretsApplicationError {
  final int secretUsageId;

  const FailedToDeregisterSecretUsageError(this.secretUsageId, Object? cause)
    : super(
        'Failed to deregister secret usage with ID $secretUsageId.',
        cause: cause,
      );
}

class FailedToImportSeedSecretError extends SecretsApplicationError {
  const FailedToImportSeedSecretError(Object? cause)
    : super('Failed to import seed bytes.', cause: cause);
}

class FailedToImportMnemonicSecretError extends SecretsApplicationError {
  const FailedToImportMnemonicSecretError(Object? cause)
    : super('Failed to import mnemonic.', cause: cause);
}

class FailedToGetSecretError extends SecretsApplicationError {
  final Fingerprint? fingerprint;

  const FailedToGetSecretError(this.fingerprint, Object? cause)
    : super('Failed to get secret for $fingerprint.', cause: cause);
}

class FailedToLoadAllStoredSecretsError extends SecretsApplicationError {
  const FailedToLoadAllStoredSecretsError(Object? cause)
    : super('Failed to load all stored secrets.', cause: cause);
}

class FailedToListUsedSecretsError extends SecretsApplicationError {
  const FailedToListUsedSecretsError(Object? cause)
    : super('Failed to list used secrets.', cause: cause);
}

class FailedToCreateNewMnemonicSecretError extends SecretsApplicationError {
  const FailedToCreateNewMnemonicSecretError(Object? cause)
    : super('Failed to create mnemonic secret.', cause: cause);
}

class FailedToGetSecretUsagesByConsumerError extends SecretsApplicationError {
  final SecretConsumer? consumer;

  const FailedToGetSecretUsagesByConsumerError({this.consumer, Object? cause})
    : super(
        'Failed to get secret usages for consumer $consumer.',
        cause: cause,
      );
}

class FailedToLoadLegacySecretsError extends SecretsApplicationError {
  const FailedToLoadLegacySecretsError(Object? cause)
    : super('Failed to load legacy secrets.', cause: cause);
}
