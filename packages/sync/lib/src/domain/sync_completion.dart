import 'package:primitives/primitives.dart';

import 'sync_failure.dart';
import 'wallet_key.dart';
import 'wallet_revision.dart';

/// The completed native mode, with observations captured under writer ownership.
enum SyncMode { initialScan, revealedScripts, discovery, targeted, liquid }

final class SyncCompletion {
  final SyncMode mode;
  final Duration elapsed;
  final WalletRevision? revision;
  final Set<String>? incomingTxids;

  /// The targeted transactions this pass proved visible. Null when the pass
  /// queried no target scripts. An empty set proves no target visible, not
  /// that all targets are absent. Only conclusive targets are listed here.
  final Set<String>? visibleTransactionIds;

  /// The targeted transactions this pass conclusively judged after querying
  /// at least one of their revealed wallet scripts. Null when the pass
  /// queried no target scripts. A target missing from this set stays unknown,
  /// even if the pass queried a script it touches.
  final Set<String>? coveredTransactionIds;

  const SyncCompletion(
    this.mode,
    this.elapsed, {
    this.revision,
    this.incomingTxids,
    this.visibleTransactionIds,
    this.coveredTransactionIds,
  });

  SyncCompletion committed(WalletRevision stamp) => SyncCompletion(
    mode,
    elapsed,
    revision: stamp,
    incomingTxids: incomingTxids,
    visibleTransactionIds: visibleTransactionIds,
    coveredTransactionIds: coveredTransactionIds,
  );
}

final class SyncStarted {
  final WalletKey key;
  final int runId;

  const SyncStarted(this.key, this.runId);
}

final class SyncFinished {
  final WalletKey key;
  final Result<SyncCompletion, SyncFailure> result;
  final int runId;

  const SyncFinished(this.key, this.result, {required this.runId});
}
