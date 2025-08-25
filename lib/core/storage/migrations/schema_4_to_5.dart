import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema4To5 {
  static Future<void> migrate(Migrator m, Schema5 schema5) async {
    // Add birthday column in wallet_metadatas table
    final walletMetadatas = schema5.walletMetadatas;
    await m.addColumn(walletMetadatas, walletMetadatas.birthday);

    await m.createTable(schema5.bip85Derivations);
  }
}
