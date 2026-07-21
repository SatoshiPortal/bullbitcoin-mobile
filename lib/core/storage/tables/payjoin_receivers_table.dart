import 'package:drift/drift.dart';

@DataClassName('PayjoinReceiverRow')
class PayjoinReceivers extends Table {
  TextColumn get id => text()();
  TextColumn get address => text()();
  BoolColumn get isTestnet => boolean()();
  TextColumn get receiver => text()();
  TextColumn get walletId => text()();
  TextColumn get pjUri => text()();
  Int64Column get maxFeeRateSatPerVb => int64()();
  IntColumn get createdAt => integer()();
  IntColumn get expireAfterSec => integer()();
  BlobColumn get originalTxBytes => blob().nullable()();
  TextColumn get originalTxId => text().nullable()();
  IntColumn get amountSat => integer().nullable()();
  TextColumn get proposalPsbt => text().nullable()();
  TextColumn get txId => text().nullable()();
  BoolColumn get isExpired => boolean()();
  BoolColumn get isCompleted => boolean()();
  // Set when WE broadcast the original transaction instead of completing a
  // real payjoin (below-minimum decline, manual "send without payjoin", or
  // expiry with an original available) — see PayjoinStatus.aborted. Kept
  // distinct from [isCompleted], which now means only "a real payjoin
  // proposal was broadcast" — conflating the two used to make every
  // fallback broadcast display as a completed payjoin.
  BoolColumn get isAborted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
