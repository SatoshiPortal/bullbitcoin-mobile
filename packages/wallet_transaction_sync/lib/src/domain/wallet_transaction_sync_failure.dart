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
