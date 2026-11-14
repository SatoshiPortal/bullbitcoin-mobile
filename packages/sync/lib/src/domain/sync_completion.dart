import 'package:primitives/primitives.dart';

import 'transaction_sync_failure.dart';
import 'wallet_key.dart';
import 'wallet_revision.dart';

/// The completed native mode, with observations captured under writer ownership.
enum SyncMode { initialScan, revealedScripts, discovery, liquid }

final class SyncCompletion {
  final SyncMode mode;
  final Duration elapsed;
  final WalletRevision? revision;
  final Set<String>? incomingTxids;

  const SyncCompletion(
    this.mode,
    this.elapsed, {
    this.revision,
    this.incomingTxids,
  });

  SyncCompletion committed(WalletRevision stamp) => SyncCompletion(
    mode,
    elapsed,
    revision: stamp,
    incomingTxids: incomingTxids,
  );
}

final class SyncFinished {
  final WalletKey key;
  final Result<SyncCompletion, TransactionSyncFailure> result;

  const SyncFinished(this.key, this.result);
}
