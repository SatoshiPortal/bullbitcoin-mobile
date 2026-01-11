import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';

sealed class SeedsApplicationError implements Exception {
  final String message;
  final Object? cause;
  const SeedsApplicationError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

/// Useful base when a domain rule bubbles up through a use case.
class BusinessRuleFailed extends SeedsApplicationError {
  final SeedsDomainError domainError;
  BusinessRuleFailed(this.domainError)
    : super(domainError.message, cause: domainError);
}

class SeedInUseError extends SeedsApplicationError {
  final String fingerprint;

  const SeedInUseError(this.fingerprint)
    : super('Cannot delete seed $fingerprint because it is in use.');
}

class FailedToDeleteSeedError extends SeedsApplicationError {
  final String fingerprint;

  const FailedToDeleteSeedError(this.fingerprint, Object? cause)
    : super('Failed to delete seed $fingerprint.', cause: cause);
}

class FailedToRegisterSeedUsageError extends SeedsApplicationError {
  final String fingerprint;

  const FailedToRegisterSeedUsageError(this.fingerprint, Object? cause)
    : super('Failed to register usage for seed $fingerprint.', cause: cause);
}

class FailedToDeregisterSeedUsageError extends SeedsApplicationError {
  final int seedUsageId;

  const FailedToDeregisterSeedUsageError(this.seedUsageId, Object? cause)
    : super(
        'Failed to deregister seed usage with ID $seedUsageId.',
        cause: cause,
      );
}

class FailedToImportSeedBytesError extends SeedsApplicationError {
  const FailedToImportSeedBytesError(Object? cause)
    : super('Failed to import seed bytes.', cause: cause);
}

class FailedToImportSeedMnemonicError extends SeedsApplicationError {
  const FailedToImportSeedMnemonicError(Object? cause)
    : super('Failed to import seed mnemonic.', cause: cause);
}

class FailedToGetSeedSecretError extends SeedsApplicationError {
  final String fingerprint;

  const FailedToGetSeedSecretError(this.fingerprint, Object? cause)
    : super('Failed to get seed secret for $fingerprint.', cause: cause);
}

class FailedToLoadAllStoredSeedSecretsError extends SeedsApplicationError {
  const FailedToLoadAllStoredSeedSecretsError(Object? cause)
    : super('Failed to load all stored seed secrets.', cause: cause);
}

class FailedToListUsedSeedsError extends SeedsApplicationError {
  const FailedToListUsedSeedsError(Object? cause)
    : super('Failed to list used seeds.', cause: cause);
}

class FailedToCreateNewSeedMnemonicError extends SeedsApplicationError {
  const FailedToCreateNewSeedMnemonicError(Object? cause)
    : super('Failed to create mnemonic seed.', cause: cause);
}

class SeedUsageNotFoundError extends SeedsApplicationError {
  final SeedUsagePurpose purpose;
  final String consumerRef;

  const SeedUsageNotFoundError({
    required this.purpose,
    required this.consumerRef,
  }) : super(
         'Seed usage not found for purpose $purpose and consumerRef $consumerRef.',
       );
}

class FailedToGetSeedUsageByConsumerError extends SeedsApplicationError {
  final SeedUsagePurpose purpose;
  final String consumerRef;

  const FailedToGetSeedUsageByConsumerError({
    required this.purpose,
    required this.consumerRef,
    Object? cause,
  }) : super(
         'Failed to get seed usage for purpose $purpose and consumerRef $consumerRef.',
         cause: cause,
       );
}

class FailedToLoadLegacySeedsError extends SeedsApplicationError {
  const FailedToLoadLegacySeedsError(Object? cause)
    : super('Failed to load legacy seeds.', cause: cause);
}
