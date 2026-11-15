import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:sync/sync.dart';

/// The category of a broadcast sync refused or could not complete. Sync has
/// already reduced the native cause and the servers' replies; no text is kept.
BroadcastFailureCategory broadcastFailureCategory(SyncFailure failure) =>
    switch (failure) {
      SyncBroadcastRejectedFailure() => BroadcastFailureCategory.rejected,
      SyncAlreadyInChainFailure() => BroadcastFailureCategory.alreadyInChain,
      SyncConnectionFailure() => BroadcastFailureCategory.connection,
      SyncUnauthorizedNetworkFailure() =>
        BroadcastFailureCategory.authorization,
      // An unknown outcome, mixed servers included: the transaction may have
      // been relayed, so it is never reported as rejected.
      _ => BroadcastFailureCategory.unexpected,
    };

/// The repositories throw [CategorizedBroadcastException]; anything else is a
/// cause nobody classified.
BroadcastFailureCategory mapBroadcastFailure(Object error) =>
    BroadcastFailureCategory.of(error);
