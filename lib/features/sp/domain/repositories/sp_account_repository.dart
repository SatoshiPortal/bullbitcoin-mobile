import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:meta/meta.dart';

/// Outbound port over the Silent Payments Rust FFI (`SpAccount`).
///
/// The application layer depends on this interface; the concrete
/// `BwkSpAccountRepository` adapter owns the single live FFI session
/// (notification stream + dispose lifecycle + sqlite handle) per data dir.
/// Nothing above the application layer touches `SpAccount` directly.
///
/// The public surface uses domain types only. The wire/FFI view types stay in
/// `data/` behind the mappers; the confirmed [SpTxDraft] wraps the FFI
/// simulation opaquely and round-trips it UNCHANGED into
/// `finalizeSignBroadcast` (the pin invariant).
abstract interface class SpAccountRepository {
  /// Create an account from the mnemonic, reusing any existing on-disk sqlite
  /// stores. Establishes the live session. Used both for first-time setup and
  /// to reconstruct the session on load (see `EnsureSpSessionUsecase`).
  ///
  /// Throws when a session is already live: the adapter owns exactly one
  /// `SpAccount`, so callers must `dispose()` first. Every legitimate path
  /// (recreate, revoke, ensure) already tears the session down before
  /// establishing a new one, so this guard only fires on a real double-create.
  Future<void> createFromMnemonic({
    required SpNetwork network,
    required String mnemonic,
    required String blindbitUrl,
    required String electrumUrl,
  });

  /// Tear down the live session: cancel the notification stream, join the
  /// Rust thread, drop the sqlite handle. Idempotent; rethrows a timeout
  /// error if the inner lock is still held so callers can decline to reopen.
  Future<void> dispose();

  bool get hasSession;

  /// True while a recreate/revoke is tearing the session down and (for
  /// recreate) re-establishing it. `EnsureSpSessionUsecase` must not start a
  /// competing establishment while this is set, so the self-heal that fires
  /// when the notification stream closes mid-teardown cannot race the create.
  bool get teardownInProgress;

  /// Bracket a recreate/revoke teardown so a concurrent self-heal cannot
  /// establish a second session. Call [beginTeardown] before `dispose()` and
  /// [endTeardown] after the create (recreate) or after the delete (revoke).
  /// [endTeardown] is idempotent.
  void beginTeardown();
  void endTeardown();

  /// Revoke the wallet on disk. Writes the `.revoked` sentinel BEFORE tearing
  /// the session down (T1.3: a self-heal racing the teardown then sees a
  /// revoked dir and refuses to reload it), disposes the live session so the
  /// sqlite handle is released, then recursively deletes the account dir. On a
  /// partial delete it re-creates the sentinel and emits [SpSetupChanged]
  /// (observers drop the SP card) before rethrowing, so a leftover dir can
  /// never be reloaded. Idempotent when already revoked or the dir is gone.
  Future<void> revokeOnDisk();

  /// Move the account dir aside to a fresh backup so a failed recreate can roll
  /// back. No-op when the dir is absent. Returns whether a backup was taken.
  Future<bool> backupAccountDir();

  /// Roll back a recreate: delete the (partial) account dir, then restore the
  /// backup taken by [backupAccountDir] in its place. Returns whether a backup
  /// was restored.
  Future<bool> restoreAccountDir();

  /// Drop the backup taken by [backupAccountDir] after a recreate succeeded.
  /// Swallows a file-locked failure (a stale backup is harmless).
  Future<void> discardBackup();

  /// True when a `.revoked` sentinel sits in the account dir (a prior revoke
  /// deleted or tried to delete the wallet). Callers treat this as not set up.
  Future<bool> hasRevokedSentinel();

  /// Delete a stale account dir left by a failed revoke (sentinel + sqlite
  /// still present) so a fresh setup can recreate it. Throws on delete failure.
  Future<void> wipeStaleAccountDir();

  /// Current snapshot (SP address + balance + scan state). Throws if no
  /// session is established.
  SpWallet snapshot();
  SpBalance balance();
  bool get isScanning;
  int? get lastScannedHeight;

  /// Whether a scan is running, tracked in Dart from notifications (no FFI), so
  /// callers can skip blocking reads while the scan holds the inner lock.
  bool get isScanningCached;

  // receive address (USER-TRIGGERED reveal)

  /// Reveal a fresh taproot receive address to hand out. Each call derives the
  /// next never-before-issued address (advances + persists the receive tip);
  /// it must NEVER re-hand a previously revealed address. Call only on an
  /// explicit user "generate" action, not on every screen load.
  @useResult
  Future<Result<String, SpFailure>> generateTaprootAddress();

  @useResult
  Future<Result<List<SpPayment>, SpFailure>> history();
  @useResult
  Future<Result<List<SpCoin>, SpFailure>> coins();

  // scan (USER-TRIGGERED ONLY)

  /// The single Dart entry point to the Rust scan. Reached only via
  /// `ScanSpWalletUsecase`. `startHeight` overrides where the scan begins
  /// (null resumes from the last scanned position).
  @useResult
  Future<Result<void, SpFailure>> scanOnce({int? startHeight});
  Future<void> stopScan();

  /// Restart the taproot electrum listener in place (reconnect + re-subscribe +
  /// re-sync). Used on app foreground to recover after Android killed the
  /// backgrounded socket. No-op when there is no live session.
  Future<void> restartElectrum();

  /// Earliest height a scan may start from (taproot activation on mainnet, a
  /// low value on test networks). The scan start chooser uses it as its floor.
  int minBirthdayHeight();

  @useResult
  Future<Result<SpTxDraft, SpFailure>> preparePsbt({
    required List<SpRecipient> recipients,
    required BigInt feerateSatVb,
  });

  /// finalize -> sign -> broadcast as one irreversible, simulation-pinned step.
  /// The [draft] round-trips its opaque FFI simulation UNCHANGED, so the tx is
  /// pinned to exactly what the confirm page showed. Returns the broadcast txid.
  @useResult
  Future<Result<String, SpFailure>> finalizeSignBroadcast({
    required SpTxDraft draft,
  });

  // info reads
  //
  // `network()` returns null only when no session is established (a genuine
  // unknown); an FFI read failure throws so callers can fail closed instead of
  // treating a transient error as "no network". `backendOnline()`/`chainTip()`
  // stay tolerant (false/null on FRB Err).
  SpNetwork? network();
  bool backendOnline();

  /// Current chain tip height, or null on FRB Err / no session.
  int? chainTip();

  // notifications (broadcast view of the single-take receiver)

  Stream<SpNotification> get notifications;

  // notification debug log (for the SP settings console)

  /// Buffered notifications (oldest first), capped; survives session recycles.
  List<SpNotifLogLine> get notificationLog;

  /// Live stream of new notification log lines.
  Stream<SpNotifLogLine> get notificationLogStream;

  /// Materially-changed events (balance changes, setup created/revoked) that
  /// other features observe without depending on SP internals. Always-on
  /// (independent of whether a session is established).
  Stream<SpUpdate> get updates;

  /// Emit a [SpSetupChanged] on [updates]. Called by the revoke use case after
  /// it tears the wallet down, so observers (the wallet home) re-evaluate setup
  /// state. `createFromMnemonic` emits the same event internally on setup.
  void notifySetupChanged();
}
