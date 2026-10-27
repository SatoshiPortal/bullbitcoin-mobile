import 'dart:io';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:sqlite3/sqlite3.dart';

/// Lets a fresh Electrum client skip downloads the device already holds: the
/// wallet's transactions and confirmation anchors come from the BDK wallet,
/// the parent transactions its inputs spend come from a sidecar database.
///
/// Only public chain data is cached. The server still answers every script
/// history and header request, so discovery and reorg handling are unchanged.
/// Every method is best effort: a cache failure only costs the downloads.
final class BdkElectrumCache {
  final Database _db;

  BdkElectrumCache._(this._db);

  static String pathFor(String walletDatabasePath) =>
      '$walletDatabasePath.parents.sqlite';

  /// Opens the sidecar of [walletDatabasePath], rebuilding it when it is
  /// unreadable. Returns null when it cannot be used at all.
  static BdkElectrumCache? open(String walletDatabasePath) {
    final path = pathFor(walletDatabasePath);
    for (var attempt = 0; attempt < 2; attempt++) {
      Database? db;
      try {
        db = sqlite3.open(path);
        db.execute('PRAGMA busy_timeout = 5000');
        db.execute(
          'CREATE TABLE IF NOT EXISTS parent_transaction '
          '(txid TEXT PRIMARY KEY NOT NULL, raw BLOB NOT NULL) WITHOUT ROWID',
        );
        return BdkElectrumCache._(db);
      } catch (_) {
        db?.dispose();
        _deleteFiles(path);
      }
    }
    return null;
  }

  /// Removes the sidecar along with its wallet.
  static void delete(String walletDatabasePath) =>
      _deleteFiles(pathFor(walletDatabasePath));

  /// Seeds [client] before a scan. Only direct anchors are passed: a
  /// transitive one carries a descendant's block, not the transaction's.
  void prefill(bdk.ElectrumClient client, bdk.Wallet wallet) {
    final parents = <bdk.Transaction>[];
    try {
      parents.addAll(_storedParents());
      final canonical = wallet.transactions();
      client.populateTxCache(
        transactions: [for (final tx in canonical) tx.transaction, ...parents],
      );
      client.populateAnchorCache(
        anchors: [
          for (final tx in canonical)
            if (tx.chainPosition case bdk.ConfirmedChainPosition(
              transitively: null,
              :final confirmationBlockTime,
            ))
              bdk.TxAnchor(
                txid: tx.transaction.computeTxid(),
                anchor: confirmationBlockTime,
              ),
        ],
      );
    } catch (_) {
      // A client without a prefill still syncs, it only downloads more.
    } finally {
      for (final parent in parents) {
        parent.dispose();
      }
    }
  }

  /// Stores the parents of the wallet's transactions after a scan. [client]
  /// must be the one that scanned with prevouts: it answers from its cache.
  void rememberParents(bdk.ElectrumClient client, bdk.Wallet wallet) {
    try {
      final own = <String>{};
      final spent = <String>{};
      for (final canonical in wallet.transactions()) {
        final tx = canonical.transaction;
        own.add(tx.computeTxid().toString());
        if (tx.isCoinbase()) continue;
        for (final input in tx.input()) {
          spent.add(input.previousOutput.txid.toString());
        }
      }
      final stored = {
        for (final row in _db.select('SELECT txid FROM parent_transaction'))
          row['txid'] as String,
      };
      final missing = spent.difference(own).difference(stored);
      if (missing.isEmpty) return;

      final insert = _db.prepare(
        'INSERT OR IGNORE INTO parent_transaction (txid, raw) VALUES (?, ?)',
      );
      try {
        _db.execute('BEGIN IMMEDIATE');
        try {
          for (final txid in missing) {
            final tx = client.fetchTx(txid: bdk.Txid.fromString(hex: txid));
            try {
              if (tx.computeTxid().toString() == txid) {
                insert.execute([txid, tx.serialize()]);
              }
            } finally {
              tx.dispose();
            }
          }
          _db.execute('COMMIT');
        } catch (_) {
          _db.execute('ROLLBACK');
          rethrow;
        }
      } finally {
        insert.dispose();
      }
    } catch (_) {
      // The next scan downloads the parents again and retries.
    }
  }

  void close() => _db.dispose();

  /// Stored parents whose bytes still hash to their txid; others are dropped.
  List<bdk.Transaction> _storedParents() {
    final parents = <bdk.Transaction>[];
    final corrupt = <String>[];
    for (final row in _db.select('SELECT txid, raw FROM parent_transaction')) {
      final txid = row['txid'] as String;
      try {
        final tx = bdk.Transaction(transactionBytes: row['raw'] as Uint8List);
        if (tx.computeTxid().toString() == txid) {
          parents.add(tx);
          continue;
        }
        tx.dispose();
      } catch (_) {
        // Unparsable bytes are dropped below.
      }
      corrupt.add(txid);
    }
    for (final txid in corrupt) {
      _db.execute('DELETE FROM parent_transaction WHERE txid = ?', [txid]);
    }
    return parents;
  }

  static void _deleteFiles(String path) {
    for (final suffix in const ['', '-journal', '-wal', '-shm']) {
      try {
        final file = File('$path$suffix');
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // Left for the next open or delete to retry.
      }
    }
  }
}
