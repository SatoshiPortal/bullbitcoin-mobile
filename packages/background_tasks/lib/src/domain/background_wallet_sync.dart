import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Consumer contract. Integration binds this to the single native writer.
/// Implementations never release native ownership on a scheduling timeout.
abstract interface class BackgroundWalletSync {
  Future<Result<BackgroundSyncOutcome, BackgroundSyncFailure>> synchronize(
    WalletKey key, {
    required bool allowInitialScan,
  });
}

/// A real sync completion, never a snapshot reload. The writer captures
/// foreground visibility at completion, before awaiting outbox persistence.
/// Incoming txids are complete, so a later sync can replay an interrupted
/// outbox handoff. Only discoveries from THIS sync may become seen.
final class BackgroundSyncOutcome {
  final WalletRevision revision;
  final Set<String> incomingTxids;
  final Set<String> discoveredTxids;
  final DateTime completedAt;
  final bool completedInForeground;

  BackgroundSyncOutcome({
    required this.revision,
    required Iterable<String> incomingTxids,
    required Iterable<String> discoveredTxids,
    required this.completedAt,
    required this.completedInForeground,
  }) : incomingTxids = Set.unmodifiable(incomingTxids),
       discoveredTxids = Set.unmodifiable(discoveredTxids) {
    if (this.incomingTxids.any((id) => id.isEmpty) ||
        !this.incomingTxids.containsAll(this.discoveredTxids)) {
      throw ArgumentError('Discoveries must be a subset of incoming payments');
    }
  }
}

sealed class BackgroundSyncFailure extends Failure {
  const BackgroundSyncFailure();
}

final class BackgroundSyncBusyFailure extends BackgroundSyncFailure {
  const BackgroundSyncBusyFailure();
}

final class BackgroundSyncConnectionFailure extends BackgroundSyncFailure {
  const BackgroundSyncConnectionFailure();
}

final class BackgroundSyncUnsupportedNetworkFailure
    extends BackgroundSyncFailure {
  const BackgroundSyncUnsupportedNetworkFailure();
}

final class BackgroundSyncInitialScanRequiredFailure
    extends BackgroundSyncFailure {
  const BackgroundSyncInitialScanRequiredFailure();
}

final class BackgroundSyncNeedsRepairFailure extends BackgroundSyncFailure {
  /// Exact stamp observed under writer ownership, not the admission read.
  final WalletRevision revision;
  const BackgroundSyncNeedsRepairFailure(this.revision);
}
