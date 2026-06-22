import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 12 to 13
///
/// Changes to swaps table:
/// - Adds 'refund_fees' column: network fees actually paid by a refund
///   transaction (previously misrecorded into 'claim_fees')
/// - Adds 'was_direct_payment' column: marks reverse swaps settled by a
///   Magic Routing Hint direct payment (no lockup existed, nothing to claim)
/// - Backfills status 'refunded' for swaps stored as 'completed' that have a
///   refund txid: a refunded swap is a failed payment, not a successful one
/// - Adds 'recovered' column: marks swaps reconstructed by the restore/rescue
///   flow rather than created in-app. Fields not derivable from the Boltz
///   restore response + on-chain data are untrustworthy for these and hidden
///   in the UI.
///
/// Changes to settings table:
/// - Adds 'exchange_testnet_basic_auth_username'/'...password' columns: in-app
///   HTTP basic auth creds gating the testnet exchange web frontend
class Schema12To13 {
  static Future<void> migrate(Migrator m, Schema13 schema13) async {
    try {
      await m.addColumn(schema13.swaps, schema13.swaps.refundFees);
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    try {
      await m.addColumn(schema13.swaps, schema13.swaps.wasDirectPayment);
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    try {
      await m.addColumn(schema13.swaps, schema13.swaps.recovered);
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    await m.database.customStatement(
      "UPDATE swaps SET status = 'refunded' "
      "WHERE status = 'completed' AND refund_txid IS NOT NULL",
    );

    try {
      await m.addColumn(
        schema13.settings,
        schema13.settings.exchangeTestnetBasicAuthUsername,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
    try {
      await m.addColumn(
        schema13.settings,
        schema13.settings.exchangeTestnetBasicAuthPassword,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
  }
}
