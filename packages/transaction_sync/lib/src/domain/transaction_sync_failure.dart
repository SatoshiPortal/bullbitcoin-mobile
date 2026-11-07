import 'package:primitives/primitives.dart';

/// Recoverable outcomes. No foreign exception, descriptor or endpoint is kept.
sealed class TransactionSyncFailure extends Failure {
  const TransactionSyncFailure();
}

final class TransactionSyncBusyFailure extends TransactionSyncFailure {
  const TransactionSyncBusyFailure();
}

final class TransactionSyncNotFoundFailure extends TransactionSyncFailure {
  const TransactionSyncNotFoundFailure();
}

final class TransactionSyncUnsupportedNetworkFailure
    extends TransactionSyncFailure {
  const TransactionSyncUnsupportedNetworkFailure();
}

final class TransactionSyncInvalidCatalogFailure
    extends TransactionSyncFailure {
  const TransactionSyncInvalidCatalogFailure();
}

final class TransactionSyncStorageFailure extends TransactionSyncFailure {
  const TransactionSyncStorageFailure();
}

final class TransactionSyncConnectionFailure extends TransactionSyncFailure {
  const TransactionSyncConnectionFailure();
}

final class TransactionSyncNeedsRepairFailure extends TransactionSyncFailure {
  const TransactionSyncNeedsRepairFailure();
}

final class TransactionSyncRestartRequiredFailure
    extends TransactionSyncFailure {
  const TransactionSyncRestartRequiredFailure();
}
