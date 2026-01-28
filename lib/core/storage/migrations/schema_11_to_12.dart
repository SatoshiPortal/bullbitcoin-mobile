import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 11 to 12
///
/// Changes to labels table:
/// - Adds 'id' column as autoincrement primary key
/// - Renames 'ref' column to 'reference'
/// - Removes 'spendable' column
/// - Changes primary key from composite (label, ref) to single (id)
/// - Adds unique constraint on (label, reference)
///
/// Changes to autoSwap table:
/// - Resets showWarning to true for all entries
class Schema11To12 {
  static Future<void> migrate(Migrator m, Schema12 schema12) async {
    final schema11 = Schema11(database: m.database);

    // For structural changes involving a new autoincrement primary key,
    // we need to manually recreate the table:
    // 1. Fetch all existing data from the old table
    // 2. Delete the old table
    // 3. Create new table with correct schema
    // 4. Insert the data back

    // Step 1: Fetch all existing labels data
    final existingLabels = await m.database.select(schema11.labels).get();

    // Step 2: Delete old labels table
    await m.deleteTable(schema11.labels.actualTableName);

    // Step 3: Create new labels table with new schema
    await m.createTable(schema12.labels);

    // Step 4: Insert existing data into new table
    // id will be auto-generated, ref -> reference, spendable is dropped
    for (final row in existingLabels) {
      final origin = row.readNullable<String>('origin');
      await m.database
          .into(schema12.labels)
          .insert(
            RawValuesInsertable({
              'label': Variable<String>(row.read<String>('label')),
              'reference': Variable<String>(row.read<String>('ref')),
              'type': Variable<String>(row.read<String>('type')),
              if (origin != null) 'origin': Variable<String>(origin),
            }),
          );
    }
    // Reset showWarning to true for all users so they see the warning
    await m.database
        .update(schema12.autoSwap)
        .write(RawValuesInsertable({'show_warning': const Constant<int>(1)}));

    // MempoolServers table: add enableSsl column
    final mempoolServers = schema12.mempoolServers;
    await m.addColumn(mempoolServers, mempoolServers.enableSsl);
  }
}
