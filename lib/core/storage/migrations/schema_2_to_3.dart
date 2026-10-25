import 'package:bb_mobile/core/storage/migrations/migration_guards.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema2To3 {
  static Future<void> migrate(Migrator m, Schema3 schema3) async {
    // Create WalletAddressHistory table. 3→4 drops it again, so skip it once
    // 3→4 has replaced wallet_metadatas.source.
    if (!await m.hasColumn('wallet_metadatas', 'source')) return;
    await m.createTable(schema3.walletAddressHistory);
  }
}
