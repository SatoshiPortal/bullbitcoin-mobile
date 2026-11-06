import 'package:transaction_sync/transaction_sync.dart';

/// A real sync completion, never a snapshot reload. The writer captures
/// foreground visibility at completion, before awaiting outbox persistence.
/// Incoming txids are complete, so a later sync can replay an interrupted
/// outbox handoff. Only discoveries from THIS sync may become seen.
final class WalletSyncCompletion {
  final WalletRevision revision;
  final Set<String> incomingTxids;
  final Set<String> discoveredTxids;
  final DateTime completedAt;
  final bool completedInForeground;

  WalletSyncCompletion({
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
