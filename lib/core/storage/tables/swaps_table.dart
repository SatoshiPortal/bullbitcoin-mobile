import 'package:drift/drift.dart';

enum SwapDirection { send, receive, onchain }

@DataClassName('SwapRow')
class Swaps extends Table {
  TextColumn get id => text().withLength(min: 12, max: 12)();
  TextColumn get type => text()();
  TextColumn get direction => textEnum<SwapDirection>()();
  TextColumn get status => text()();
  BoolColumn get isTestnet => boolean()();
  IntColumn get keyIndex => integer()();
  IntColumn get creationTime => integer()();
  IntColumn get completionTime => integer().nullable()();
  TextColumn get receiveWalletId => text().nullable()();
  TextColumn get sendWalletId => text().nullable()();
  TextColumn get invoice => text().nullable()();
  TextColumn get paymentAddress => text().nullable()();
  IntColumn get paymentAmount => integer().nullable()();
  TextColumn get receiveAddress => text().nullable()();
  TextColumn get receiveTxid => text().nullable()();
  TextColumn get sendTxid => text().nullable()();
  TextColumn get preimage => text().nullable()();
  TextColumn get refundAddress => text().nullable()();
  TextColumn get refundTxid => text().nullable()();
  IntColumn get boltzFees => integer().nullable()();
  IntColumn get lockupFees => integer().nullable()();
  IntColumn get claimFees => integer().nullable()();
  IntColumn get serverNetworkFees => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
