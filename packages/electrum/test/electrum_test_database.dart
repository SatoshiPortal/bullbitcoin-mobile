import 'package:drift/drift.dart';
import 'package:electrum/storage.dart';

import 'electrum_test_database.drift.dart';

@DriftDatabase(tables: [Transactions, ElectrumServers, ElectrumSettings])
class ElectrumTestDatabase extends $ElectrumTestDatabase {
  @override
  final int schemaVersion;

  ElectrumTestDatabase(super.executor, {this.schemaVersion = 1});
}
