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
