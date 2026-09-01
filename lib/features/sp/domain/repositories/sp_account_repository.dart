import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The Silent Payments account: the single live session, the read-only views of
/// what it holds, and the event streams other layers observe.
///
/// The public surface uses domain types only; the wire/FFI view types stay in
/// `data/` behind the mappers.
abstract interface class SpAccountRepository {
  /// Create an account from the mnemonic, reusing any existing on-disk sqlite
  /// stores. Establishes the live session. Used both for first-time setup and
  /// to reconstruct the session on load (see `EnsureSpSessionUsecase`).
  ///
  /// Returns `Err(SpSessionBusy)` when a session is already live: exactly one
  /// `SpAccount` exists, so callers must `dispose()` first. Every legitimate
  /// path (recreate, revoke, ensure) tears the session down before establishing
  /// a new one, so that guard only fires on a real programmer error.
  ///
  /// This is the only call that carries the mnemonic across the FFI boundary,
  /// so its failures carry fixed text: no error string derived from the
  /// arguments is ever interpolated into the returned failure.
  @useResult
  Future<Result<void, SpFailure>> createFromMnemonic({
    required BitcoinNetwork network,
    required String mnemonic,
    required String blindbitUrl,
    required String electrumUrl,
    int fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    int matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  });

  /// Tear down the live session: cancel the notification stream, join the Rust
  /// thread, drop the sqlite handle. Idempotent; returns `Err` (the session is
  /// kept) when the inner lock is still held, so callers can decline to reopen.
  @useResult
  Future<Result<void, SpFailure>> dispose();

  bool get hasSession;

  /// True while a recreate/revoke is tearing the session down and (for
  /// recreate) re-establishing it. `EnsureSpSessionUsecase` must not start a
  /// competing establishment while this is set, so the self-heal that fires
  /// when the notification stream closes mid-teardown cannot race the create.
  bool get teardownInProgress;

  /// Bracket a recreate/revoke teardown so a concurrent self-heal cannot
  /// establish a second session. Call [beginTeardown] before `dispose()` and
  /// [endTeardown] after the create (recreate) or after the delete (revoke).
  ///
  /// Calls nest: every [beginTeardown] must be matched by exactly one
  /// [endTeardown], so an inner teardown finishing does not unblock an outer
  /// one still running. A revoke and a recreate can overlap, and the first to
  /// finish must not clear the guard for the other.
  void beginTeardown();
  void endTeardown();

  /// Current snapshot (SP address + balance + scan state). `Err` when no
  /// session is established.
  @useResult
  Result<SpWallet, SpFailure> snapshot();

  @useResult
  Result<SpBalance, SpFailure> balance();

  /// The payment history, each entry already flagged with whether it landed on
  /// the SP sub-account (the coin set says so, and both reads live here).
  @useResult
  Future<Result<List<SpPayment>, SpFailure>> history();
  @useResult
  Future<Result<List<SpCoin>, SpFailure>> coins();

  /// `Ok(null)` only when no session is established (a genuine unknown); an FFI
  /// read failure is `Err` so callers can fail closed instead of treating a
  /// transient error as "no network".
  @useResult
  Result<BitcoinNetwork?, SpFailure> network();

  /// Tolerant on purpose: false on an FFI error rather than throwing.
  bool backendOnline();

  /// Latest header-store tip seen from header progress, or null if unknown.
  int? chainTip();

  /// Live chain tip read from the electrum backend. Needs a live session.
  /// Unlike [chainTip] this does not depend on header progress, which has not
  /// reported anything yet right after creation.
  @useResult
  Result<int, SpFailure> currentBlockHeight();

  /// Earliest height a scan may start from (taproot activation on mainnet, a
  /// low value on test networks). The scan start chooser uses it as its floor.
  /// Needs a live session.
  @useResult
  Result<int, SpFailure> minBirthdayHeight();

  /// Broadcast view of the single-take Rust receiver.
  Stream<SpNotification> get notifications;

  /// Buffered notifications (oldest first), capped; survives session recycles.
  List<SpNotifLogLine> get notificationLog;

  /// Live stream of new notification log lines.
  Stream<SpNotifLogLine> get notificationLogStream;

  /// Materially-changed events (balance changes, setup created/revoked) that
  /// other features observe without depending on SP internals. Always-on
  /// (independent of whether a session is established).
  Stream<SpUpdate> get updates;

  /// Emit a setup-changed event on [updates]. Called by the revoke use case
  /// after it tears the wallet down, so observers (the wallet home) re-evaluate
  /// setup state. `createFromMnemonic` emits the same event internally on setup.
  void notifySetupChanged();

  /// Emit a balance-changed event with the current unified balance. Used by SP
  /// data loads that observe a fresh snapshot outside the notification path.
  void notifyBalanceChanged(Sats totalUnifiedSat);
}
