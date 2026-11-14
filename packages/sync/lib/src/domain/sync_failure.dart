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
    SyncFreezeImportRequiredFailure() => 'freeze_import_required',
    SyncFreezeStoreLostFailure() => 'freeze_store_lost',
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

/// The one-time import of the app's freeze table has not completed: no
/// freeze is known yet, so no freeze change and no spend is admitted. The
/// foreground retries it; the background never runs it.
final class SyncFreezeImportRequiredFailure extends SyncFailure {
  const SyncFreezeImportRequiredFailure();
}

/// The import completed once, but the freeze store is now missing, unreadable
/// or incomplete. Freezes may have been lost: nothing is admitted until an
/// explicit recovery finds the store whole again. Never recreated empty.
final class SyncFreezeStoreLostFailure extends SyncFailure {
  const SyncFreezeStoreLostFailure();
}
