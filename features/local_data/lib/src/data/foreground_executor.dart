import 'dart:io';

import 'package:bull_local_data/src/domain/local_database.dart';
import 'package:bull_sqlite/bull_sqlite.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;

/// The foreground executor on the main database, as the app has always opened it — through `drift_flutter`, shared across isolates — with the key set first on every connection.
QueryExecutor foregroundExecutor(UnlockedDatabase database) {
  final file = File(database.path);
  final key = database.key;
  return driftDatabase(
    name: p.basenameWithoutExtension(file.path),
    native: DriftNativeOptions(
      databaseDirectory: () async => file.parent,
      // Stream queries stay in sync across isolates, and drift serialises concurrent transactions instead of reporting "database is locked".
      shareAcrossIsolates: true,
      setup: (connection) =>
          SqliteCipher.configure(connection, key, fullSync: true),
    ),
  );
}
