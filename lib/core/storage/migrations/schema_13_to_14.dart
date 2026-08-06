import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:drift/drift.dart';

/// Migration from version 13 to 14
///
/// Changes to settings table:
/// - Adds 'payjoin_enabled' column (default false): whether payjoin is
///   enabled globally. Existing installs are backfilled to false via the
///   column default — payjoin is opt-in, since it trades exposing one of
///   the receiver's UTXOs for on-chain privacy, a trade-off the user must
///   explicitly consent to (see the payjoin settings screen's disclosure).
/// - Adds 'payjoin_min_amount_sat' column (default 10000): the minimum
///   receive amount below which an incoming payjoin is declined and the
///   payment broadcasts normally instead (anti-probing, BIP78).
/// - Adds 'payjoin_expire_after_sec' column (default 86400, i.e. 24 hours):
///   the payjoin session lifetime, in seconds, shared by the receive and
///   send sides.
/// All three columns carry a DB default, so `addColumn` backfills every
/// existing row automatically; no manual backfill statement is needed.
///
/// Changes to payjoin_receivers and payjoin_senders tables:
/// - Adds 'is_aborted' column (default false) to both: set when WE
///   broadcast the original transaction instead of completing a real
///   payjoin (below-minimum decline, manual "send without payjoin", or
///   expiry with an original available) — see PayjoinStatus.aborted.
///   Previously this outcome was folded into 'is_completed', which made
///   every plain fallback broadcast display as a completed payjoin.
///
/// Adds the dismissed_announcements table:
/// - Records which home announcements the user has dismissed (announcement id
///   + dismissal timestamp). New table, created empty.
///
/// Adds the order_swaps table and indexes for crash-safe Exchange transfers.
class Schema13To14 {
  static Future<void> migrate(Migrator m, Schema14 schema14) async {
    try {
      await m.addColumn(schema14.settings, schema14.settings.payjoinEnabled);
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
    try {
      await m.addColumn(
        schema14.settings,
        schema14.settings.payjoinMinAmountSat,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
    try {
      await m.addColumn(
        schema14.settings,
        schema14.settings.payjoinExpireAfterSec,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    try {
      await m.addColumn(
        schema14.payjoinReceivers,
        schema14.payjoinReceivers.isAborted,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
    try {
      await m.addColumn(
        schema14.payjoinSenders,
        schema14.payjoinSenders.isAborted,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    // New dismissed_announcements table: one row per home announcement the
    // user has dismissed (announcement id + dismissal timestamp). A brand-new
    // table, so existing installs simply start with zero dismissals.
    try {
      await m.createTable(schema14.dismissedAnnouncements);
    } catch (e) {
      // Idempotency guard: only swallow "table already exists" (a re-run over a
      // partially-applied migration) — log it so a driver wording change
      // surfaces instead of silently becoming a hard failure.
      if (!e.toString().contains('already exists')) rethrow;
      log.warning(
        'Schema13To14: dismissed_announcements already exists — skipping create',
        error: e,
      );
    }

    await m.createTable(schema14.orderSwaps);
    await m.createIndex(schema14.orderSwapsRequestId);
    await m.createIndex(schema14.orderSwapsLocalStatus);
    await m.createIndex(schema14.orderSwapsSourceWallet);
    await m.createIndex(schema14.orderSwapsDestinationWallet);
    await m.createIndex(schema14.orderSwapsBitcoinTxid);
    await m.createIndex(schema14.orderSwapsLiquidTxid);
    await m.createIndex(schema14.orderSwapsLocalPayinTxid);
  }
}
