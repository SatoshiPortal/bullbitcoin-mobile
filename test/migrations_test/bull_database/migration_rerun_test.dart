import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v10.dart' as v10;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bull_rerun');
  });

  tearDown(() => dir.delete(recursive: true));

  // drift writes user_version after each step, outside the step, so a stale
  // write from a second connection or a crash between the two makes the next
  // launch re-run steps over a database that is already further along. Every
  // step must leave such a database, and the user's data in it, unchanged.
  group('re-running every step over a database at the current schema', () {
    final origins = <String, Future<File> Function()>{
      'a fresh install': () async {
        final file = File('${dir.path}/origin.sqlite');
        await _open(file);
        return file;
      },
      'an install migrated from schema 1': () async {
        final file = File('${dir.path}/origin.sqlite');
        final seeded = v1.DatabaseAtV1(NativeDatabase(file));
        await seeded.customSelect('SELECT 1').get();
        await seeded.close();
        await _open(file);
        return file;
      },
    };

    for (final MapEntry(key: origin, value: create) in origins.entries) {
      for (var from = 1; from < SqliteDatabase.currentSchemaVersion; from++) {
        test('from user_version $from on $origin keeps the schema and every '
            'row', () async {
          final origin = await create();
          _seedUserData(origin);
          final before = _dump(origin);

          final file = origin.copySync('${dir.path}/rerun.sqlite');
          _setUserVersion(file, from);

          final db = SqliteDatabase(NativeDatabase(file));
          final userVersion = await db
              .customSelect('PRAGMA user_version')
              .map((row) => row.read<int>('user_version'))
              .getSingle();
          expect(userVersion, SqliteDatabase.currentSchemaVersion);
          await db.validateDatabaseSchema();
          await db.close();

          expect(_dump(file), before);
          _expectUserData(file);
        });
      }
    }
  });

  test('a step that fails part-way leaves the database as it was', () async {
    final file = File('${dir.path}/${SqliteDatabase.name}.sqlite');
    final seeded = v10.DatabaseAtV10(NativeDatabase(file));
    await seeded.customSelect('SELECT 1').get();
    await seeded.close();

    // 10→11 adds settings.theme_mode, creates prices and rebuilds auto_swap
    // before it inserts the fulcrum electrum server. Make that insert fail.
    _execute(
      file,
      'CREATE TRIGGER fail_10_to_11 BEFORE INSERT ON electrum_servers '
      "BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
    );

    final failing = SqliteDatabase(NativeDatabase(file));
    await expectLater(
      failing.customSelect('SELECT 1').get(),
      throwsA(anything),
    );
    await failing.close();

    expect(_userVersion(file), 10);
    expect(_columns(file, 'settings'), isNot(contains('theme_mode')));
    expect(_columns(file, 'auto_swap'), isNot(contains('show_warning')));
    expect(_columns(file, 'prices'), isEmpty);

    _execute(file, 'DROP TRIGGER fail_10_to_11');
    final relaunch = SqliteDatabase(NativeDatabase(file));
    await relaunch.customSelect('SELECT 1').get();
    await relaunch.validateDatabaseSchema();
    await relaunch.close();
    expect(_userVersion(file), SqliteDatabase.currentSchemaVersion);
  });
}

Future<void> _open(File file) async {
  final db = SqliteDatabase(NativeDatabase(file));
  await db.customSelect('SELECT 1').get();
  await db.close();
}

void _seedUserData(File file) {
  final db = sqlite3.open(file.path);
  try {
    if (db.select('SELECT 1 FROM settings').isEmpty) {
      db.execute(
        'INSERT INTO settings (environment, bitcoin_unit, language, currency, '
        "hide_amounts, is_superuser) VALUES ('mainnet', 'btc', 'en', 'CAD', "
        '0, 0)',
      );
    }
    db.execute(
      "UPDATE settings SET theme_mode = 'dark', use_tor_proxy = 1, "
      'tor_proxy_port = 9150, is_dev_mode_enabled = 1, '
      'is_error_reporting_enabled = 1',
    );
    for (var i = 0; i < 5; i++) {
      db.execute(
        'INSERT INTO labels (label, reference, type, origin) '
        "VALUES ('label $i', 'txid$i', 'tx', 'wallet')",
      );
    }
    db.execute(
      'INSERT INTO wallet_metadatas (id, master_fingerprint, xpub_fingerprint, '
      'is_encrypted_vault_tested, is_physical_backup_tested, xpub, '
      'external_public_descriptor, internal_public_descriptor, signer, '
      'signer_device, is_default, label, birthday, bitcoin_sync_source) VALUES '
      "('73c5da0a/84h/0h/0h', '73c5da0a', 'e0b0c1d2', 1, 0, 'xpub6C', "
      "'wpkh([73c5da0a/84h/0h/0h]xpub6C/0/*)', "
      "'wpkh([73c5da0a/84h/0h/0h]xpub6C/1/*)', 'local', NULL, 1, 'Savings', "
      "'2024-04-20T00:00:00.000', 'compactBlockFilters')",
    );
    db.execute(
      'INSERT INTO swaps (id, type, direction, status, is_testnet, key_index, '
      'creation_time, server_network_fees, refund_txid) VALUES '
      "('swap1', 'lnSend', 'send', 'completed', 0, 3, 1700000000, 250, NULL), "
      "('swap2', 'lnReceive', 'receive', 'refunded', 0, 4, 1700000100, 300, "
      "'refundtxid')",
    );
    db.execute('UPDATE auto_swap SET enabled = 0, show_warning = 0');
    db.execute('UPDATE electrum_settings SET stop_gap = 50');
    db.execute(
      'INSERT INTO electrum_servers (url, is_testnet, is_liquid, priority, '
      "is_custom) VALUES ('ssl://custom.example:50002', 0, 0, 7, 1)",
    );
    db.execute('UPDATE mempool_settings SET use_for_fee_estimation = 0');
    db.execute('UPDATE mempool_servers SET enable_ssl = 0');
    db.execute('UPDATE recoverbull SET is_permission_granted = 1');
  } finally {
    db.dispose();
  }
}

void _expectUserData(File file) {
  final db = sqlite3.open(file.path);
  try {
    final settings = db.select('SELECT * FROM settings').single;
    expect(settings['theme_mode'], 'dark');
    expect(settings['use_tor_proxy'], 1);
    expect(settings['tor_proxy_port'], 9150);
    expect(db.select('SELECT * FROM labels'), hasLength(5));
    final wallet = db.select('SELECT * FROM wallet_metadatas').single;
    expect(wallet['id'], '73c5da0a/84h/0h/0h');
    expect(wallet['signer'], 'local');
    expect(wallet['birthday'], '2024-04-20T00:00:00.000');
    expect(wallet['bitcoin_sync_source'], 'compactBlockFilters');
    expect(
      db
          .select('SELECT id, status FROM swaps ORDER BY id')
          .map((row) => '${row['id']}:${row['status']}'),
      ['swap1:completed', 'swap2:refunded'],
    );
    final autoSwaps = db.select('SELECT * FROM auto_swap');
    expect(autoSwaps, isNotEmpty);
    for (final autoSwap in autoSwaps) {
      expect(autoSwap['enabled'], 0);
      expect(autoSwap['show_warning'], 0);
    }
    for (final row in db.select('SELECT * FROM electrum_settings')) {
      expect(row['stop_gap'], 50);
    }
    final custom = db.select(
      'SELECT * FROM electrum_servers WHERE is_custom = 1',
    );
    expect(custom.map((row) => row['url']), ['ssl://custom.example:50002']);
    for (final row in db.select('SELECT * FROM mempool_settings')) {
      expect(row['use_for_fee_estimation'], 0);
    }
    for (final row in db.select('SELECT * FROM recoverbull')) {
      expect(row['is_permission_granted'], 1);
    }
  } finally {
    db.dispose();
  }
}

/// Every table's schema and rows, order-independent.
Map<String, List<String>> _dump(File file) {
  final db = sqlite3.open(file.path);
  try {
    final dump = <String, List<String>>{
      'sqlite_master': db
          .select(
            "SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE "
            "'sqlite_%' ORDER BY type, name",
          )
          .map((row) => row.toString())
          .toList(),
    };
    final tables = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE "
      "'sqlite_%' ORDER BY name",
    );
    for (final table in tables) {
      final name = table['name'] as String;
      dump[name] =
          db
              .select('SELECT * FROM "$name"')
              .map((row) => row.toString())
              .toList()
            ..sort();
    }
    return dump;
  } finally {
    db.dispose();
  }
}

List<String> _columns(File file, String table) {
  final db = sqlite3.open(file.path);
  try {
    return db
        .select('SELECT name FROM pragma_table_info(?)', [table])
        .map((row) => row['name'] as String)
        .toList();
  } finally {
    db.dispose();
  }
}

int _userVersion(File file) {
  final db = sqlite3.open(file.path);
  try {
    return db.userVersion;
  } finally {
    db.dispose();
  }
}

void _setUserVersion(File file, int version) {
  final db = sqlite3.open(file.path);
  try {
    db.userVersion = version;
  } finally {
    db.dispose();
  }
}

void _execute(File file, String sql) {
  final db = sqlite3.open(file.path);
  try {
    db.execute(sql);
  } finally {
    db.dispose();
  }
}
