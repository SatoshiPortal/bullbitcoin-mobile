import 'package:primitives/primitives.dart';

sealed class WalletTransactionSyncFailure extends Failure {
  const WalletTransactionSyncFailure();
}

final class SnapshotNotInitializedFailure extends WalletTransactionSyncFailure {
  const SnapshotNotInitializedFailure();
}

final class WalletRegistrationMismatchFailure
    extends WalletTransactionSyncFailure {
  const WalletRegistrationMismatchFailure();
}

final class WalletSourceStateMissingFailure
    extends WalletTransactionSyncFailure {
  const WalletSourceStateMissingFailure();
}

final class WalletSourceStateIncompatibleFailure
    extends WalletTransactionSyncFailure {
  const WalletSourceStateIncompatibleFailure();
}

final class DeletedWalletFailure extends WalletTransactionSyncFailure {
  const DeletedWalletFailure();
}

enum SourceFailureReason { unavailable, rejected, unknown }

final class SourceFailure extends WalletTransactionSyncFailure {
  final SourceFailureReason reason;
  final String? safeMessage;

  const SourceFailure(this.reason, {this.safeMessage});
}

/// The wallet's local storage could not apply or persist an update. Retryable:
/// the source itself answered.
final class SourceStorageFailure extends WalletTransactionSyncFailure {
  const SourceStorageFailure();
}

final class SourceObservationMismatchFailure
    extends WalletTransactionSyncFailure {
  const SourceObservationMismatchFailure();
}

final class ExtractionFailure extends WalletTransactionSyncFailure {
  final String? safeMessage;

  const ExtractionFailure({this.safeMessage});
}

final class CoordinationTimeoutFailure extends WalletTransactionSyncFailure {
  const CoordinationTimeoutFailure();
}

final class DeletionFailure extends WalletTransactionSyncFailure {
  final String? safeMessage;

  const DeletionFailure({this.safeMessage});
}

final class SnapshotExpiredFailure extends WalletTransactionSyncFailure {
  const SnapshotExpiredFailure();
}

final class InvalidPaginationFailure extends WalletTransactionSyncFailure {
  const InvalidPaginationFailure();
}

/// The wallet has never been scanned and the request refused to run its first
/// scan: a stop-gap scan of a whole history belongs to the foreground.
final class InitialScanRequiredFailure extends WalletTransactionSyncFailure {
  const InitialScanRequiredFailure();
}

/// A supplied birthday is later than the explicit reference clock.
final class InvalidWalletBirthdayFailure extends WalletTransactionSyncFailure {
  const InvalidWalletBirthdayFailure();
}
