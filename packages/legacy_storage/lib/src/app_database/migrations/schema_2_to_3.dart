import 'package:drift/drift.dart';

import 'migration_guards.dart';
import '../sqlite_database.steps.dart';

class Schema2To3 {
  static Future<void> migrate(Migrator m, Schema3 schema3) async {
    // Create WalletAddressHistory table. 3→4 drops it again, so skip it once
    // 3→4 has replaced wallet_metadatas.source.
    if (!await m.hasColumn('wallet_metadatas', 'source')) return;
    await m.createTable(schema3.walletAddressHistory);
  }
}
