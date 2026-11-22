import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

const importId = 'sample-from-v16';

class SampleDatabase extends GeneratedDatabase {
  final Future<void> Function()? afterSchemaCreated;

  SampleDatabase(
    File file,
    String fixtureKey, {
    bool background = false,
    this.afterSchemaCreated,
  }) : super(
         NativeDatabase(
           file,
           enableMigrations: !background,
           setup: (db) {
             db.execute('PRAGMA busy_timeout = 2000');
             db.execute("PRAGMA cipher = 'chacha20'");
             db.execute("PRAGMA key = 'raw:$fixtureKey'");
             if (!background) db.execute('PRAGMA journal_mode = WAL');
             db.execute('PRAGMA synchronous = FULL');
           },
         ),
       );

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE IF NOT EXISTS sample (id INTEGER PRIMARY KEY, data TEXT)',
      );
      await afterSchemaCreated?.call();
    },
  );

  Future<List<String>> readSamples() async => [
    for (final row in await customSelect(
      'SELECT data FROM sample ORDER BY id',
    ).get())
      row.read<String>('data'),
  ];
}

Database createLegacy(File source) {
  final database = sqlite3.open(source.path);
  database.execute('PRAGMA journal_mode = WAL');
  database.execute('CREATE TABLE sample (id INTEGER PRIMARY KEY, data TEXT)');
  database.execute('INSERT INTO sample VALUES (1, ?), (2, ?)', ['one', 'two']);
  database.userVersion = 16;
  return database;
}

Future<Result<void, LegacyImportFailure>> importSamples(
  File source,
  SampleDatabase destination, {
  Future<void> Function(String step)? pause,
}) => importLegacyDatabase(
  id: importId,
  source: source,
  sourceSchemaVersion: 16,
  destination: destination,
  copyAndVerify: (source) async {
    await pause?.call('claim');
    final rows = source.select('SELECT id, data FROM sample ORDER BY id');
    for (final row in rows) {
      await destination.customStatement('INSERT INTO sample VALUES (?, ?)', [
        row['id'],
        row['data'],
      ]);
      await pause?.call('row-${row['id']}');
    }
    final imported = await destination.readSamples();
    await pause?.call('verify');
    return imported.join(',') == 'one,two';
  },
);
