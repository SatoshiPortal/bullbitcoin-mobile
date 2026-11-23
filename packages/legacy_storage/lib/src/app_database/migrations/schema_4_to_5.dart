import 'package:drift/drift.dart';

import 'migration_guards.dart';
import '../sqlite_database.steps.dart';

class Schema4To5 {
  static Future<void> migrate(Migrator m, Schema5 schema5) async {
    // Add birthday column in wallet_metadatas table
    final walletMetadatas = schema5.walletMetadatas;
    await m.addColumnIfMissing(walletMetadatas, walletMetadatas.birthday);
    await m.createTable(schema5.bip85Derivations);
    final autoSwaps = schema5.autoSwap;
    await m.addColumnIfMissing(autoSwaps, autoSwaps.recipientWalletId);
  }
}
