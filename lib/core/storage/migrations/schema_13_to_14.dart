import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:drift/drift.dart';

/// Migration from version 13 to 14
///
/// Adds the dismissed_announcements table:
/// - Records which home announcements the user has dismissed (announcement id
///   + dismissal timestamp). New table, created empty.
///
/// Schema 14 also briefly carried the Payjoin policy columns on `settings` and
/// an `is_aborted` flag on the payjoin tables. Payjoin now owns its own
/// database (payjoin.sqlite, see the bull_payjoin package), and 14 was never
/// released — every tag up to v6.12.5 ships schema 13 — so those columns were
/// folded out of this step rather than added and then migrated away.
///
/// Adds the order_swaps table and indexes for crash-safe Exchange transfers.
class Schema13To14 {
  static Future<void> migrate(Migrator m, Schema14 schema14) async {
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
