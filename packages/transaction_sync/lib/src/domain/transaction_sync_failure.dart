import 'package:primitives/primitives.dart';

/// Recoverable outcomes. No foreign exception, descriptor or endpoint is kept.
sealed class TransactionSyncFailure extends Failure {
  const TransactionSyncFailure();

  /// Fixed support-log codes survive identifier redaction and carry no data.
  String get logCode => switch (this) {
    TransactionSyncBusyFailure() => 'busy',
    TransactionSyncNotFoundFailure() => 'not_found',
    TransactionSyncUnsupportedNetworkFailure(:final authorization) =>
      authorization ? 'authorization' : 'unsupported_network',
    TransactionSyncInvalidCatalogFailure() => 'invalid_catalog',
    TransactionSyncStorageFailure() => 'storage',
    TransactionSyncConnectionFailure() => 'connection',
    TransactionSyncNeedsRepairFailure() => 'needs_repair',
    TransactionSyncRestartRequiredFailure() => 'restart_required',
    TransactionSyncInitialScanRequiredFailure() => 'initial_scan_required',
  };
}

final class TransactionSyncBusyFailure extends TransactionSyncFailure {
  const TransactionSyncBusyFailure();
}

final class TransactionSyncNotFoundFailure extends TransactionSyncFailure {
  const TransactionSyncNotFoundFailure();
}

final class TransactionSyncUnsupportedNetworkFailure
    extends TransactionSyncFailure {
  final bool authorization;
  const TransactionSyncUnsupportedNetworkFailure({this.authorization = false});
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

final class TransactionSyncInitialScanRequiredFailure
    extends TransactionSyncFailure {
  const TransactionSyncInitialScanRequiredFailure();
}
