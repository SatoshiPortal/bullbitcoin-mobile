import 'package:bb_mobile/core/infra/database/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema2To3 {
  static Future<void> migrate(Migrator m, Schema3 schema3) async {
    // Create WalletAddressHistory table
    await m.createTable(schema3.walletAddressHistory);
  }
}
