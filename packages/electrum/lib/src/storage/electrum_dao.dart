import 'package:drift/drift.dart';

import 'electrum_servers_table.drift.dart';
import 'electrum_settings_table.drift.dart';
import 'transactions_table.drift.dart';

/// Queries use the tables on the host connection, including its transaction
/// and migration policy. No second database file is opened here.
final class ElectrumDao extends DatabaseAccessor<GeneratedDatabase> {
  late final electrumServers = attachedDatabase.allTables
      .whereType<$ElectrumServersTable>()
      .single;
  late final electrumSettings = attachedDatabase.allTables
      .whereType<$ElectrumSettingsTable>()
      .single;
  late final transactions = attachedDatabase.allTables
      .whereType<$TransactionsTable>()
      .single;

  ElectrumDao(super.attachedDatabase);

  $$ElectrumServersTableTableManager get serverRows =>
      $$ElectrumServersTableTableManager(attachedDatabase, electrumServers);
  $$ElectrumSettingsTableTableManager get settingsRows =>
      $$ElectrumSettingsTableTableManager(attachedDatabase, electrumSettings);
  $$TransactionsTableTableManager get transactionRows =>
      $$TransactionsTableTableManager(attachedDatabase, transactions);
}
