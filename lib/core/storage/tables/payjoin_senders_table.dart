import 'package:drift/drift.dart';

@DataClassName('PayjoinSenderRow')
class PayjoinSenders extends Table {
  TextColumn get uri => text()();
  BoolColumn get isTestnet => boolean()();
  TextColumn get sender => text()();
  TextColumn get walletId => text()();
  TextColumn get originalPsbt => text()();
  TextColumn get originalTxId => text()();
  IntColumn get amountSat => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get expireAfterSec => integer()();
  TextColumn get proposalPsbt => text().nullable()();
  TextColumn get txId => text().nullable()();
  BoolColumn get isExpired => boolean()();
  BoolColumn get isCompleted => boolean()();
  // See PayjoinReceivers.isAborted for the rationale — same distinction on
  // the sender side (below-minimum receiver decline surfaces here too, via
  // BroadcastOriginalTransactionUsecase; manual/expiry fallback likewise).
  BoolColumn get isAborted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {uri};
}
