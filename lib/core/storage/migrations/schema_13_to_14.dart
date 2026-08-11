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
/// The table includes the nullable quoted_amount_sat column used to validate
/// server-selected amounts against the quote captured at order creation.
class Schema13To14 {
  static Future<void> migrate(Migrator m, Schema14 schema14) async {
    // New dismissed_announcements table: one row per home announcement the
    // user has dismissed (announcement id + dismissal timestamp). A brand-new
    // table, so existing installs simply start with zero dismissals.
    await _createIfNotExists(
      () => m.createTable(schema14.dismissedAnnouncements),
      'dismissed_announcements table',
    );

    await _createIfNotExists(
      () => m.createTable(schema14.orderSwaps),
      'order_swaps table',
    );
    await _createIfNotExists(
      () => m.createIndex(schema14.orderSwapsRequestId),
      'order_swaps_request_id index',
    );
    await _createIfNotExists(
      () => m.createIndex(schema14.orderSwapsLocalStatus),
      'order_swaps_local_status index',
    );
    await _createIfNotExists(
      () => m.createIndex(schema14.orderSwapsSourceWallet),
      'order_swaps_source_wallet index',
    );
    await _createIfNotExists(
      () => m.createIndex(schema14.orderSwapsDestinationWallet),
      'order_swaps_destination_wallet index',
    );
    await _createIfNotExists(
      () => m.createIndex(schema14.orderSwapsBitcoinTxid),
      'order_swaps_bitcoin_txid index',
    );
    await _createIfNotExists(
      () => m.createIndex(schema14.orderSwapsLiquidTxid),
      'order_swaps_liquid_txid index',
    );
    await _createIfNotExists(
      () => m.createIndex(schema14.orderSwapsLocalPayinTxid),
      'order_swaps_local_payin_txid index',
    );

    await _addColumnIfNotExists(
      () => m.addColumn(
        schema14.autoSwap,
        schema14.autoSwap.boltzFallbackUrl,
      ),
      'auto_swap.boltz_fallback_url column',
    );
  }
}

Future<void> _createIfNotExists(
  Future<void> Function() create,
  String description,
) async {
  try {
    await create();
  } catch (e) {
    // Idempotency guard: only swallow "already exists" (a re-run over a
    // partially-applied migration) — log it so a driver wording change
    // surfaces instead of silently becoming a hard failure.
    if (!e.toString().contains('already exists')) rethrow;
    log.warning(
      'Schema13To14: $description already exists — skipping create',
      error: e,
    );
  }
}

Future<void> _addColumnIfNotExists(
  Future<void> Function() add,
  String description,
) async {
  try {
    await add();
  } catch (e) {
    if (!e.toString().contains('duplicate column name')) rethrow;
    log.warning(
      'Schema13To14: $description already exists — skipping add',
      error: e,
    );
  }
}
