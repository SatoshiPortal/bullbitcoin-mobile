import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Adds crash-safe local persistence for Exchange order swaps.
class Schema13To14 {
  static Future<void> migrate(Migrator m, Schema14 schema14) async {
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
