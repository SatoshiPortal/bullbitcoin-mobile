import 'package:drift/drift.dart';

@DataClassName('OrderSwapRow')
@TableIndex(name: 'order_swaps_request_id', unique: true, columns: {#requestId})
@TableIndex(name: 'order_swaps_local_status', columns: {#localStatus})
@TableIndex(name: 'order_swaps_source_wallet', columns: {#sourceWalletId})
@TableIndex(
  name: 'order_swaps_destination_wallet',
  columns: {#destinationWalletId},
)
@TableIndex(name: 'order_swaps_bitcoin_txid', columns: {#bitcoinTransactionId})
@TableIndex(name: 'order_swaps_liquid_txid', columns: {#liquidTransactionId})
@TableIndex(
  name: 'order_swaps_local_payin_txid',
  columns: {#localPayinTransactionId},
)
class OrderSwaps extends Table {
  TextColumn get localId => text()();
  TextColumn get requestId => text().nullable()();
  TextColumn get orderId => text().nullable().unique()();
  TextColumn get purpose => text()();
  TextColumn get environment => text()();
  TextColumn get inNetwork => text()();
  TextColumn get outNetwork => text()();
  BoolColumn get isInAmountFixed => boolean()();
  IntColumn get requestedAmountSat => integer()();
  TextColumn get sourceWalletId => text().nullable()();
  TextColumn get destinationWalletId => text().nullable()();
  TextColumn get destination => text()();
  TextColumn get fallback => text()();
  TextColumn get bitcoinAddress => text().nullable()();
  TextColumn get liquidAddress => text().nullable()();
  TextColumn get lightningInvoice => text().nullable()();
  IntColumn get payinAmountSat => integer().nullable()();
  IntColumn get payoutAmountSat => integer().nullable()();
  TextColumn get payinCurrency => text().nullable()();
  TextColumn get payoutCurrency => text().nullable()();
  TextColumn get payinMethod => text().nullable()();
  TextColumn get payoutMethod => text().nullable()();
  TextColumn get orderType => text().nullable()();
  TextColumn get orderStatus => text().nullable()();
  TextColumn get payinStatus => text().nullable()();
  TextColumn get payoutStatus => text().nullable()();
  TextColumn get messageCode => text().nullable()();
  TextColumn get bitcoinTransactionId => text().nullable()();
  TextColumn get liquidTransactionId => text().nullable()();
  TextColumn get localPayinTransactionId => text().nullable()();
  TextColumn get signedPayinTransaction => text().nullable()();
  BoolColumn get payinIsPsbt => boolean().nullable()();
  IntColumn get orderNumber => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get serverCreatedAt => dateTime().nullable()();
  DateTimeColumn get confirmationDeadline => dateTime().nullable()();
  DateTimeColumn get sentAt => dateTime().nullable()();
  TextColumn get localStatus => text()();
  DateTimeColumn get lastPolledAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get serverCompletedAt => dateTime().nullable()();
  DateTimeColumn get labelsAppliedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}
