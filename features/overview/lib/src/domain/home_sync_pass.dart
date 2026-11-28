import 'package:sync/sync.dart' show WalletKey;

import 'sync_trigger.dart';

/// How one requested foreground sync round ended, without exposing the
/// coordinator's exception or the per-kind failures behind it.
enum HomeSyncOutcome {
  /// Every requested kind settled.
  completed,

  /// Every requested kind was already busy; the running pass owns the work.
  busy,

  /// At least one requested kind failed. Balances may be stale.
  failed,
}

/// The foreground sync work Home can request and observe.
///
/// It is a port, not a repository: Home never reads a wallet through it, and
/// the Overview coordinator remains the only sync queue.
abstract interface class HomeSyncPass {
  /// Covers the whole foreground queue, including discovery and queued kinds.
  bool get isSyncPassActive;

  Stream<bool> get activity;

  Future<HomeSyncOutcome> sync({required SyncTrigger trigger});
}

/// One chain's Electrum reachability, projected without the network owner's
/// value type. A busy writer or a deferred initial scan is not a down server,
/// so producers only emit outcomes they consider meaningful.
typedef HomeSyncStart = ({WalletKey key, int runId});

typedef HomeElectrumOutcome = ({
  WalletKey key,
  int runId,
  bool isLiquid,
  bool success,
});
