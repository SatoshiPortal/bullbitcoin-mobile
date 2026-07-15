import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 13 to 14
///
/// Changes to settings table:
/// - Adds 'payjoin_min_amount_sat' column (default 10000): the minimum
///   receive amount below which a payjoin is not offered. The column carries
///   a DB default, so `addColumn` backfills every existing row to 10000; no
///   manual backfill is needed.
/// - Adds 'payjoin_expire_after_sec' column (default 60): the payjoin
///   session lifetime, in seconds, shared by both the receive and send
///   sides. Same backfill-via-default behaviour as the column above.
class Schema13To14 {
  static Future<void> migrate(Migrator m, Schema14 schema14) async {
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
  }
}
