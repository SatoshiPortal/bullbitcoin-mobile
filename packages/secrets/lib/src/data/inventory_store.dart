import 'dart:async';
import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../domain/domain.dart';
import 'database_key_repository.dart';
import 'encrypted_database.dart';
import 'secrets_database.dart';

const inventoryModule = 'secrets';

/// The keyed native connection is local to the isolate. Closing the Drift
/// executor acknowledges closure of the underlying SQLite handle.
final class InventoryStore {
  final SecretsDatabase database;
  final LifecycleHandle _handle;

  const InventoryStore._(this.database, this._handle);

  static Future<Result<InventoryStore, DatabaseOpenFailure>> open(
    File file,
    LifecycleAdmission admission, {
    required bool existing,
  }) async {
    if (existing) {
      // An admitted inventory lives in its main file. Check it before anything
      // can create or interpret it: a sidecar alone is not an inventory, and
      // an empty file is not an old schema to wait out.
      try {
        final length = _lengthIfPresent(file);
        if (length == null) {
          return const Err(
            DatabaseFileUnavailable(DatabaseFileProblem.missing),
          );
        }
        if (length == 0 && _lengthIfPresent(File('${file.path}-wal')) == null) {
          return const Err(
            DatabaseFileUnavailable(DatabaseFileProblem.unreadable),
          );
        }
      } on FileSystemException {
        return const Err(
          DatabaseFileUnavailable(DatabaseFileProblem.inaccessible),
        );
      }
    }
    final settled = Completer<void>();
    SecretsDatabase? database;
    final handle = admission.track(() async {
      await settled.future;
      await database?.close();
    });
    var published = false;
    try {
      final opened = await openEncryptedDatabase(
        DatabaseKeyRepository(),
        module: inventoryModule,
        name: 'main',
        file: file,
        existingSchemaVersion: existing ? 1 : null,
      );
      switch (opened) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final selected = SecretsDatabase(value);
          database = selected;
          await selected
              .customSelect('SELECT 1 FROM access_state LIMIT 1')
              .get();
          published = true;
          return Ok(InventoryStore._(selected, handle));
      }
    } on SqliteException catch (error) {
      return Err(DatabaseFileUnavailable(databaseFileProblemOf(error)));
    } finally {
      settled.complete();
      if (!published) await handle.close();
    }
  }

  Future<void> close() => _handle.close();
}

// Only a missing path is absent: any other error propagates.
int? _lengthIfPresent(File file) {
  try {
    return file.lengthSync();
  } on PathNotFoundException {
    return null;
  }
}
