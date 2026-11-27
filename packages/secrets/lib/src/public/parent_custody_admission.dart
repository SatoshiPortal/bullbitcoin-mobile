import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Host-owned exclusion between publishing a seed obligation and deleting it.
///
/// Acquire before the owner's metadata/native locks. The callback must publish
/// its durable obligation before returning; a handle alone is not an obligation.
/// Never wrap an admitted callback in a timeout that releases its exclusion.
abstract interface class ParentCustodyAdmissionPort {
  @useResult
  Future<Result<T, ParentCustodyFailure>> runExclusive<T>(
    Fingerprint parent,
    Future<Result<T, ParentCustodyFailure>> Function(ParentCustodyLease) action,
  );
}

enum ParentCustodyState { ready, deleting, deleted }

/// Scoped metadata authority, invalid after the admission callback returns.
/// State writes are synchronous and durable before they return.
abstract interface class ParentCustodyLease {
  @useResult
  Result<ParentCustodyState, ParentCustodyFailure> readState();

  @useResult
  Result<void, ParentCustodyFailure> markDeleting();

  @useResult
  Result<void, ParentCustodyFailure> markDeleted();

  /// Explicit foreground reconciliation only: the trusted host must first fetch
  /// the parent through Secrets and reconcile every owner's obligations under
  /// this same admission, or explicitly import it and publish its durable
  /// wallet-catalog reference. Import may clear deleting as well as deleted;
  /// fetching a handle alone must never clear either tombstone.
  @useResult
  Result<void, ParentCustodyFailure> reconcilePresent();
}

sealed class ParentCustodyFailure extends Failure {
  const ParentCustodyFailure();
}

final class ParentCustodyBusyFailure extends ParentCustodyFailure {
  const ParentCustodyBusyFailure();
}

final class ParentCustodyStorageFailure extends ParentCustodyFailure {
  const ParentCustodyStorageFailure();
}

final class ParentCustodyStateFailure extends ParentCustodyFailure {
  const ParentCustodyStateFailure();
}

/// Permanent state evidence is missing, malformed or incompatible. Foreground
/// callers must refuse explicitly; never recreate ready from a seed handle.
final class ParentCustodyMetadataFailure extends ParentCustodyFailure {
  const ParentCustodyMetadataFailure();
}

/// The seed could not be re-read after admission; no catalog may be published.
final class ParentCustodySeedUnavailableFailure extends ParentCustodyFailure {
  const ParentCustodySeedUnavailableFailure();
}

final class ParentCustodyReferencedFailure extends ParentCustodyFailure {
  const ParentCustodyReferencedFailure();
}

final class ParentCustodyInventoryFailure extends ParentCustodyFailure {
  const ParentCustodyInventoryFailure();
}

/// Deletion may already have happened; preserve the durable tombstone.
final class ParentCustodyDeletionFailure extends ParentCustodyFailure {
  const ParentCustodyDeletionFailure();
}

/// The seed has no tested backup, so deleting it would destroy the only copy.
final class ParentCustodyBackupRequiredFailure extends ParentCustodyFailure {
  const ParentCustodyBackupRequiredFailure();
}

/// The backup owner could not prove a backup either way. The state is unknown,
/// never absent: deletion is refused.
final class ParentCustodyBackupUnavailableFailure extends ParentCustodyFailure {
  const ParentCustodyBackupUnavailableFailure();
}
