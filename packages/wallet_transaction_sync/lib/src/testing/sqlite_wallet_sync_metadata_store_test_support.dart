import '../data/sqlite_wallet_sync_metadata_store.dart';
import 'dart:async';

/// Test-only construction surface. This library is intentionally not exported
/// by `wallet_transaction_sync.dart`.
final class SqliteWalletSyncMetadataStoreTestSupport {
  static Future<SqliteWalletSyncMetadataStore> open({
    required String databasePath,
    Duration busyTimeout = const Duration(milliseconds: 250),
    Duration actorCommandDelay = Duration.zero,
    String? killActorOnCommand,
    bool failAfterObservationUpdate = false,
    bool failCheckpoint = false,
    Duration? coordinationAcquisitionTimeout = const Duration(seconds: 30),
    String? gateHoldCommand,
    String? gateHeldFile,
    String? gateReleaseFile,
  }) => runZoned(
    () => SqliteWalletSyncMetadataStore.open(
      databasePath: databasePath,
      busyTimeout: busyTimeout,
    ),
    zoneValues: {
      'wallet_transaction_sync.metadata_test_config': {
        'actorCommandDelay': actorCommandDelay,
        'killActorOnCommand': killActorOnCommand,
        'failAfterObservationUpdate': failAfterObservationUpdate,
        'failCheckpoint': failCheckpoint,
        'coordinationAcquisitionTimeout': coordinationAcquisitionTimeout,
        'gateHoldCommand': gateHoldCommand,
        'gateHeldFile': gateHeldFile,
        'gateReleaseFile': gateReleaseFile,
      },
    },
  );
}
