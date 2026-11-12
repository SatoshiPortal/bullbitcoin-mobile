import 'dart:io';
import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

/// A value stored in clear before encryption. No file of the family may contain it afterwards.
const canary = 'CANARY-bull-sqlite-8c1d2f';

DatabaseKey keyOf(int seed) =>
    DatabaseKey(Uint8List.fromList(List<int>.generate(32, (i) => seed + i)));

String freshPath() {
  final directory = Directory.systemTemp.createTempSync('bull_sqlite_');
  return '${directory.path}/data.sqlite';
}

/// A plaintext WAL database in the shape of the app's: a `user_version`, a table with a blob, an index, a view, and rows only in the WAL. Returns the expected row count.
///
/// The WAL is left un-checkpointed by copying the files while the writer is still open, as a killed app leaves them.
int seedPlaintextWithUncheckpointedWal(String path) {
  final scratch = Directory.systemTemp.createTempSync('bull_sqlite_seed_');
  final source = '${scratch.path}/seed.sqlite';
  final db = sqlite3.open(source);
  db.execute('PRAGMA journal_mode = WAL;');
  db.execute('PRAGMA wal_autocheckpoint = 0;');
  db.execute('PRAGMA user_version = 16;');
  db.execute(
    'CREATE TABLE labels (id INTEGER PRIMARY KEY, label TEXT, payload BLOB);',
  );
  db.execute('CREATE INDEX labels_label ON labels (label);');
  db.execute('CREATE VIEW labelled AS SELECT label FROM labels;');
  db.execute('CREATE TABLE kv (k TEXT PRIMARY KEY, v TEXT) WITHOUT ROWID;');
  final insert = db.prepare(
    'INSERT INTO labels (label, payload) VALUES (?, ?);',
  );
  for (var i = 0; i < 500; i++) {
    insert.execute([
      i == 250 ? canary : 'label $i',
      Uint8List.fromList([i % 256, 1, 2, 3]),
    ]);
  }
  insert.close();
  db.execute("INSERT INTO kv VALUES ('secret', '$canary');");
  for (final suffix in ['', '-wal', '-shm']) {
    final file = File('$source$suffix');
    if (file.existsSync()) file.copySync('$path$suffix');
  }
  db.close();
  scratch.deleteSync(recursive: true);
  return 500;
}

/// Every byte of every file in [directory], searched for [canary].
bool canaryOnDisk(String directory) {
  final needle = canary.codeUnits;
  for (final entity in Directory(directory).listSync()) {
    if (entity is! File) continue;
    final bytes = entity.readAsBytesSync();
    outer:
    for (var i = 0; i + needle.length <= bytes.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (bytes[i + j] != needle[j]) continue outer;
      }
      return true;
    }
  }
  return false;
}

String headerOf(String path) =>
    String.fromCharCodes(File(path).readAsBytesSync().take(15));
