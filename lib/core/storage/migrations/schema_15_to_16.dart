import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 15 to 16.
///
/// Adds `send_timestamps`, which records when the app broadcast an outgoing
/// transaction.
///
/// Wallet transactions are never persisted — BDK and LWK rebuild them on every
/// sync — and their only recoverable timestamp is the block confirmation time,
/// which for an outgoing transaction lands minutes to hours after the user
/// actually sent. Recording the broadcast moment here is the only way to show
/// what a send was worth at the time it was made.
///
/// Creating the table is the whole migration. There is nothing to backfill:
/// the send moment of a transaction broadcast before this release was never
/// captured and cannot be recovered, so those transactions fall back to
/// confirmation-time anchoring, exactly as incoming ones do.
class Schema15To16 {
  static Future<void> migrate(Migrator m, Schema16 schema16) async {
    await m.createTable(schema16.sendTimestamps);
  }
}
