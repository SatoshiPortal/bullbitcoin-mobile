import 'dart:io';

import 'package:drift/native.dart';

import 'src/data/database/recoverbull_cutover.dart';
import 'src/data/database/recoverbull_database.dart';
import 'src/data/database/recoverbull_storage.dart';

RecoverBullDatabase openRecoverBullDatabaseForTesting(String path) =>
    RecoverBullDatabase.forTesting(
      NativeDatabase.createInBackground(
        File(path),
        setup: (database) {
          final version =
              database.select('PRAGMA user_version').single['user_version']
                  as int;
          if (version > RecoverBullDatabase.schema) {
            throw const RecoverBullUnsupportedSchemaException();
          }
          database.execute('PRAGMA busy_timeout = 2000');
          database.execute('PRAGMA journal_mode = WAL');
          database.execute('PRAGMA synchronous = FULL');
          database.execute('PRAGMA secure_delete = ON');
        },
      ),
    );

RecoverBullStorage recoverBullStorageForTesting(String path) =>
    RecoverBullStorage.forTesting(() async {
      final database = openRecoverBullDatabaseForTesting(path);
      try {
        await database.forceOpen();
        return database;
      } catch (_) {
        await database.close();
        rethrow;
      }
    });

RecoverBullCutover recoverBullCutoverForTesting({
  required File file,
  required File standalone,
}) {
  final path = file.path;
  return RecoverBullCutover.withTestExecutor(
    file: file,
    standalone: standalone,
    regtest: false,
    executor: () => NativeDatabase(File(path)),
  );
}
