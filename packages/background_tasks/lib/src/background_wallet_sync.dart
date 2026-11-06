import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Consumer contract. Integration binds this to the single native writer.
/// Implementations never release native ownership on a scheduling timeout.
abstract interface class BackgroundWalletSync {
  @useResult
  Future<Result<BackgroundSyncOutcome, BackgroundSyncFailure>> synchronize(
    WalletKey key, {
    required bool allowInitialScan,
  });
}

/// Committed observations for background reconciliation. The writer binding
/// records WalletSyncCompletion through notifications before returning success.
final class BackgroundSyncOutcome {
  final WalletRevision revision;
  final Set<String> incomingTxids;
  final DateTime completedAt;

  BackgroundSyncOutcome({
    required this.revision,
    required Iterable<String> incomingTxids,
    required this.completedAt,
  }) : incomingTxids = Set.unmodifiable(incomingTxids) {
    if (this.incomingTxids.any((id) => id.isEmpty)) {
      throw ArgumentError('Incoming payment identities must not be empty');
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
