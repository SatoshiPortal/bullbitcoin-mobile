import 'package:primitives/primitives.dart';
import 'wallet_revision.dart';

/// Recoverable outcomes. No foreign exception, descriptor or endpoint is kept.
sealed class SyncFailure extends Failure {
  const SyncFailure();

  /// Fixed support-log codes survive identifier redaction and carry no data.
  String get logCode => switch (this) {
    SyncBusyFailure() => 'busy',
    SyncNotFoundFailure() => 'not_found',
    SyncUnsupportedNetworkFailure() => 'unsupported_network',
    SyncUnauthorizedNetworkFailure() => 'authorization',
    SyncInvalidCatalogFailure() => 'invalid_catalog',
    SyncStorageFailure() => 'storage',
    SyncConnectionFailure() => 'connection',
    SyncNeedsRepairFailure() => 'needs_repair',
    SyncRestartRequiredFailure() => 'restart_required',
    SyncInitialScanRequiredFailure() => 'initial_scan_required',
    SyncInvalidAddressFailure() => 'invalid_address',
    SyncClosedFailure() => 'closed',
    SyncInvalidTransactionFailure() => 'invalid_transaction',
    SyncNotFinalizableFailure() => 'not_finalizable',
  };
}

final class SyncBusyFailure extends SyncFailure {
  const SyncBusyFailure();
}

final class SyncNotFoundFailure extends SyncFailure {
  const SyncNotFoundFailure();
}

final class SyncUnsupportedNetworkFailure extends SyncFailure {
  const SyncUnsupportedNetworkFailure();
}

/// The network is supported, but its use currently lacks authorization.
final class SyncUnauthorizedNetworkFailure extends SyncFailure {
  const SyncUnauthorizedNetworkFailure();
}

final class SyncInvalidCatalogFailure extends SyncFailure {
  const SyncInvalidCatalogFailure();
}

final class SyncStorageFailure extends SyncFailure {
  const SyncStorageFailure();
}

final class SyncConnectionFailure extends SyncFailure {
  const SyncConnectionFailure();
}

final class SyncNeedsRepairFailure extends SyncFailure {
  final WalletRevision? revision;
  const SyncNeedsRepairFailure([this.revision]);
}

final class SyncRestartRequiredFailure extends SyncFailure {
  const SyncRestartRequiredFailure();
}

final class SyncInitialScanRequiredFailure extends SyncFailure {
  const SyncInitialScanRequiredFailure();
}

final class SyncInvalidAddressFailure extends SyncFailure {
  const SyncInvalidAddressFailure();
}

/// The owning [Sync] was closed; its wallet handles refuse every operation.
final class SyncClosedFailure extends SyncFailure {
  const SyncClosedFailure();
}

/// A failure of the wallet-free chain functions: decoding, finalization,
/// broadcast and lookups. A wallet sync never returns one.
sealed class SyncChainFailure extends SyncFailure {
  const SyncChainFailure();
}

/// Bytes, a PSBT or a PSET that do not decode, exceed the decoder's bound or
/// do not describe the expected transaction.
final class SyncInvalidTransactionFailure extends SyncChainFailure {
  const SyncInvalidTransactionFailure();
}

/// A signer's PSBT, combined with the one it was given, cannot be finalized.
final class SyncNotFinalizableFailure extends SyncChainFailure {
  const SyncNotFinalizableFailure();
}
