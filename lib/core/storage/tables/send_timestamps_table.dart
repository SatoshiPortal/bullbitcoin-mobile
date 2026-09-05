import 'package:drift/drift.dart';

/// When the app broadcast an outgoing transaction.
///
/// Nothing persists wallet transactions: BDK and LWK produce them fresh on
/// every sync, and their only recoverable timestamp is the block confirmation
/// time. For an outgoing transaction that is minutes to hours after the user
/// actually sent, so the send moment is recorded here at broadcast or it is
/// lost for good.
///
/// This deliberately stores **no rate, no fiat amount and no currency**. Every
/// fiat figure in the app derives from the `Prices` cache, so two rows can
/// never disagree, and changing the settings currency cannot strand a value
/// frozen in the old one.
///
/// The table is local. A seed restore does not carry it, and an outgoing
/// transaction then falls back to confirmation-time anchoring — the same
/// behaviour incoming transactions already have.
@DataClassName('SendTimestampRow')
class SendTimestamps extends Table {
  TextColumn get txid => text()();

  /// Broadcast time, seconds since epoch, matching the units BDK and LWK use
  /// for confirmation timestamps.
  IntColumn get sentAtSecs => integer()();

  @override
  Set<Column> get primaryKey => {txid};
}
