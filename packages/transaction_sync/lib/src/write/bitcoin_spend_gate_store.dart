import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import '../../transaction_sync.dart';
import 'store_identity.dart';

/// Recovery metadata only; the native wallet remains the transaction authority.
/// Every operation runs under the wallet writer lease. Never quarantine this DB.
final class BitcoinSpendGateStore {
  final Database _db;

  BitcoinSpendGateStore(String path) : _db = _openExisting(path);

  static Database _openExisting(String path) {
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readWrite);
      db.execute('PRAGMA busy_timeout = 1000');
      db.execute('PRAGMA synchronous = FULL');
      if (db.userVersion != 1) throw const BitcoinSpendGateUnavailable();
      return db;
    } on Exception {
      db?.dispose();
      // Do not let revision-store recovery quarantine the wrong database.
      throw const BitcoinSpendGateUnavailable();
    }
  }

  static void provision(String path) {
    final marker = File('$path.provisioned');
    if (marker.existsSync() && !File(path).existsSync()) {
      throw const BitcoinSpendGateUnavailable();
    }
    final db = sqlite3.open(path);
    try {
      if (db.userVersion == 0) {
        db.execute('BEGIN IMMEDIATE');
        db.execute('''CREATE TABLE IF NOT EXISTS broadcasts (
          wallet TEXT NOT NULL, network TEXT NOT NULL,
          descriptor TEXT NOT NULL, generation INTEGER NOT NULL,
          txid TEXT NOT NULL, observed INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY(wallet, network, txid))''');
        db.userVersion = 1;
        db.execute('COMMIT');
      }
      if (db.userVersion != 1) throw const BitcoinSpendGateUnavailable();
      marker.writeAsStringSync('1\n', flush: true);
    } on Exception {
      throw const BitcoinSpendGateUnavailable();
    } finally {
      db.dispose();
    }
  }

  List<String> tracked(PublicWalletDescriptor descriptor) {
    final key = descriptor.key;
    final rows = _db.select(
      'SELECT descriptor, txid FROM broadcasts WHERE wallet=? AND network=?',
      [key.id, key.network.env.name],
    );
    // Do not filter by generation: revision recovery can reset its counter.
    // Old obligations survive reimport and may clear only on matching evidence.
    if (rows.any((row) => row['descriptor'] != descriptorDigest(descriptor))) {
      throw const BitcoinSpendGateUnavailable();
    }
    return rows.map((row) => row['txid'] as String).toList();
  }

  bool generationMismatch(WalletKey key, int generation) => _db.select(
    'SELECT 1 FROM broadcasts WHERE wallet=? AND network=? AND generation<>? LIMIT 1',
    [key.id, key.network.env.name, generation],
  ).isNotEmpty;

  bool blocked(PublicWalletDescriptor descriptor, {String? replacing}) {
    final ids = tracked(descriptor);
    if (replacing != null && ids.contains(replacing)) return true;
    return _db.select(
      'SELECT 1 FROM broadcasts WHERE wallet=? AND network=? AND observed=0 LIMIT 1',
      [descriptor.key.id, descriptor.key.network.env.name],
    ).isNotEmpty;
  }

  void accepted(
    PublicWalletDescriptor descriptor,
    int generation,
    String txid,
  ) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid)) {
      throw const BitcoinSpendGateUnavailable();
    }
    tracked(descriptor);
    _db.execute(
      'INSERT OR IGNORE INTO broadcasts (wallet,network,descriptor,generation,txid) VALUES (?,?,?,?,?)',
      [
        descriptor.key.id,
        descriptor.key.network.env.name,
        descriptorDigest(descriptor),
        generation,
        txid.toLowerCase(),
      ],
    );
  }

  /// Must precede native mutation, including recovery/discovery/rebuild.
  void requireValidation(WalletKey key) => _db.execute(
    'UPDATE broadcasts SET observed=0 WHERE wallet=? AND network=?',
    [key.id, key.network.env.name],
  );

  /// Recovery may have lost catalog entries or failed to adopt their stores.
  /// Invalidate every obligation before removing the global recovery barrier.
  void requireRecoveryValidation() =>
      _db.execute('UPDATE broadcasts SET observed=0');

  void observed(
    PublicWalletDescriptor descriptor,
    int generation,
    Set<String> txids,
  ) {
    tracked(descriptor);
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final txid in txids) {
        _db.execute(
          'UPDATE broadcasts SET observed=1, generation=? WHERE wallet=? AND network=? AND txid=?',
          [
            generation,
            descriptor.key.id,
            descriptor.key.network.env.name,
            txid,
          ],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => _db.dispose();
}

final class BitcoinSpendGateUnavailable implements Exception {
  const BitcoinSpendGateUnavailable();
}
