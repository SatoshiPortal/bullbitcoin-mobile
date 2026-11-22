import 'package:drift/drift.dart';
import 'package:electrum/storage.dart';

import 'electrum_test_database.drift.dart';

@DriftDatabase(tables: [Transactions, ElectrumServers, ElectrumSettings])
class ElectrumTestDatabase extends $ElectrumTestDatabase {
  ElectrumTestDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
