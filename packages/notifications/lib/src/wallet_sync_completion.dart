import 'package:sync/sync.dart';

/// A real sync completion, never a snapshot reload. The writer captures
/// foreground visibility at completion, before awaiting outbox persistence.
/// Complete incoming history lets the outbox derive discoveries from its stored set.
final class WalletSyncCompletion {
  final WalletRevision revision;
  final Set<String> incomingTxids;
  final DateTime completedAt;
  final bool completedInForeground;

  WalletSyncCompletion({
    required this.revision,
    required Iterable<String> incomingTxids,
    required this.completedAt,
    required this.completedInForeground,
  }) : incomingTxids = Set.unmodifiable(incomingTxids) {
    if (this.incomingTxids.any((id) => id.isEmpty)) {
      throw ArgumentError('Incoming payment identities must not be empty');
    }
  }
}
