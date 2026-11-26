import 'package:drift/drift.dart' show Variable;
import 'package:primitives/primitives.dart';

import 'backup_guard.dart';
import 'secrets_database.dart';

/// Whether Ark may notify for [parent] while the app is locked, read afresh
/// under the inventory's write lock (a PIN set concurrently is serialized with
/// this read). It reads no seed and answers a bool.
///
/// 1. [parent] belongs to at least one view with background access enabled;
///    no membership never satisfies "every view is unprotected";
/// 2. no view that contains [parent] has a credential.
///
/// An unreadable policy is a refusal. One definition serves the headless task
/// and the foreground, so an OS alarm is scheduled by the same rule in both.
Future<bool> arkNotifyPermitted(
  SecretsDatabase database,
  Fingerprint parent,
) async {
  try {
    return await inventoryWriteTransaction(database, () async {
      await serializeInventoryWrites(database);
      final rows = await database
          .customSelect(
            'SELECT v.background_enabled AS background, '
            'v.credential_id AS credential FROM view_members m '
            'JOIN views v ON v.id = m.view_id WHERE m.member = ?',
            variables: [Variable('secret:${parent.hex}')],
            readsFrom: {database.viewMembers, database.views},
          )
          .get();
      if (rows.isEmpty) return false;
      var background = false;
      for (final row in rows) {
        if (row.readNullable<String>('credential') != null) return false;
        if (row.read<bool>('background')) background = true;
      }
      return background;
    });
  } on Object {
    return false;
  }
}
