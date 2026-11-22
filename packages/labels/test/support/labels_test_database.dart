import 'package:drift/drift.dart';
import 'package:labels/frozen_utxos_table.dart';
import 'package:labels/labels_table.dart';

import 'labels_test_database.drift.dart';

@DriftDatabase(tables: [LabelsTable, FrozenUtxos])
class LabelsTestDatabase extends $LabelsTestDatabase {
  LabelsTestDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
