import 'package:bb_mobile/core/labels/data/labels_table.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_table.dart';
import 'package:bb_mobile/core/transaction/data/models/transactions_table.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_table.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'sqlite_database.g.dart';

@DriftDatabase(
  tables: [
    Transactions,
    WalletMetadatas,
    Labels,
    Settings,
    PayjoinSenders,
    PayjoinReceivers,
  ],
)
class SqliteDatabase extends _$SqliteDatabase {
  SqliteDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bullbitcoin_sqlite',
      native: const DriftNativeOptions(), // TODO(azad): constant path
    );
  }
}
