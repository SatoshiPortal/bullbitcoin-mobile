import 'dart:io';

import 'package:bull_local_data/bull_local_data.dart';
import 'package:bull_local_data/src/data/local_database_repository_impl.dart';
import 'package:bull_local_data/src/domain/usecases/unlock_local_databases_usecase.dart';
import 'package:bull_sqlite/bull_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing RecoverBull key refuses startup without replacing it', () async {
    final directory = await Directory.systemTemp.createTemp('recoverbull-key-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/recoverbull.sqlite';
    final key = DatabaseKey.fromHex('42' * 32);
    final database = sqlite3.open(path);
    SqliteCipher.configure(database, key, fullSync: true);
    database.execute('CREATE TABLE recoverbull_state (id INTEGER PRIMARY KEY)');
    database.execute('INSERT INTO recoverbull_state VALUES (1)');
    database.execute('PRAGMA user_version = 1');
    database.close();
    final before = await File(path).readAsBytes();
    final storage = _ObservedStorage()..install();
    final secrets = Secrets(scratchDirectory: () async => directory.path);
    // Other databases are new; their keys already exist so their unlock writes nothing.
    expect(
      await secrets
          .databaseKeys(module: 'bb_mobile')
          .getOrCreate(name: 'bullbitcoin_sqlite'),
      isA<Ok>(),
    );
    expect(
      await secrets
          .databaseKeys(module: 'bull_payjoin')
          .getOrCreate(name: 'payjoin'),
      isA<Ok>(),
    );
    final writes = storage.writes;
    final deletes = storage.deletes;
    final result = await UnlockLocalDatabasesUsecase(
      LocalDatabaseRepositoryImpl(
        secrets: secrets,
        paths: LocalDatabasePaths(
          main: '${directory.path}/bullbitcoin_sqlite.sqlite',
          payjoin: '${directory.path}/payjoin.sqlite',
          recoverbull: '${directory.path}/recoverbull.sqlite',
        ),
      ),
    ).execute();
    expect(result, isA<Err<UnlockedDatabases, LocalDataFailure>>());
    if (result case Err(:final failure)) {
      expect(failure, isA<LocalDataKeyMissingFailure>());
      if (failure is LocalDataKeyMissingFailure) {
        expect(failure.database.name, 'recoverbull');
      }
    }
    expect(await File(path).readAsBytes(), before);
    expect(
      storage.entries.containsKey(
        'com.bullbitcoin.secrets/dek/bull_recoverbull/recoverbull',
      ),
      isFalse,
    );
    expect(storage.writes, writes);
    expect(storage.deletes, deletes);
  });
}

final class _ObservedStorage extends FakeSecureStoragePlatform {
  int writes = 0;
  int deletes = 0;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) {
    writes++;
    return super.write(key: key, value: value, options: options);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) {
    deletes++;
    return super.delete(key: key, options: options);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) {
    deletes++;
    return super.deleteAll(options: options);
  }
}
