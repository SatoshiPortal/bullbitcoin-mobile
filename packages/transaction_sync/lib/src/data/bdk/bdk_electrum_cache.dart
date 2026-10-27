import 'dart:io';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:sqlite3/sqlite3.dart';

/// What a prefill handed the client, for the sync log.
typedef BdkElectrumCachePrefill = ({
  int transactions,
  int parents,
  int anchors,
  int droppedParents,
  bool failed,
});

/// Parents downloaded and stored after a scan, for the sync log.
typedef BdkElectrumCacheParents = ({int stored, bool failed});

/// Lets a fresh Electrum client skip downloads the device already holds: the
/// wallet's transactions and confirmation anchors come from the BDK wallet,
/// the parent transactions its inputs spend come from a sidecar database.
///
/// Only public chain data is cached. The server still answers every script
/// history and header request, so discovery and reorg handling are unchanged.
/// Every method is best effort: a cache failure only costs the downloads.
final class BdkElectrumCache {
  final Database _db;

  /// Whether [open] had to delete an unreadable sidecar.
  final bool rebuilt;

  BdkElectrumCache._(this._db, {required this.rebuilt});

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
        return BdkElectrumCache._(db, rebuilt: attempt > 0);
      } catch (_) {
        db?.dispose();
        _deleteFiles(path);
      }
    }
    return null;
  }

  /// The cache part of a sync log line: counts only, no identifiers.
  static String describe({
    required bool opened,
    required bool rebuilt,
    BdkElectrumCachePrefill? prefill,
    BdkElectrumCacheParents? parents,
  }) {
    final state = !opened
        ? 'unavailable'
        : prefill == null || prefill.failed || (parents?.failed ?? false)
        ? 'degraded'
        : rebuilt
        ? 'rebuilt'
        : 'ok';
    return 'cache=$state '
        'prefilled_txs=${prefill?.transactions ?? 0} '
        'prefilled_parents=${prefill?.parents ?? 0} '
        'anchors=${prefill?.anchors ?? 0} '
        'dropped_parents=${prefill?.droppedParents ?? 0} '
        'stored_parents=${parents?.stored ?? 0}';
  }

  /// Removes the sidecar along with its wallet.
  static void delete(String walletDatabasePath) =>
      _deleteFiles(pathFor(walletDatabasePath));

  /// Seeds [client] before a scan. Only direct anchors are passed: a
  /// transitive one carries a descendant's block, not the transaction's.
  BdkElectrumCachePrefill prefill(
    bdk.ElectrumClient client,
    bdk.Wallet wallet,
  ) {
    final parents = <bdk.Transaction>[];
    var transactions = 0;
    var anchorCount = 0;
    var dropped = 0;
    try {
      dropped = _storedParents(parents);
      final canonical = wallet.transactions();
      transactions = canonical.length;
      client.populateTxCache(
        transactions: [for (final tx in canonical) tx.transaction, ...parents],
      );
      final anchors = [
        for (final tx in canonical)
          if (tx.chainPosition case bdk.ConfirmedChainPosition(
            transitively: null,
            :final confirmationBlockTime,
          ))
            bdk.TxAnchor(
              txid: tx.transaction.computeTxid(),
              anchor: confirmationBlockTime,
            ),
      ];
      anchorCount = anchors.length;
      client.populateAnchorCache(anchors: anchors);
      return (
        transactions: transactions,
        parents: parents.length,
        anchors: anchorCount,
        droppedParents: dropped,
        failed: false,
      );
    } catch (_) {
      // A client without a prefill still syncs, it only downloads more.
      return (
        transactions: transactions,
        parents: parents.length,
        anchors: anchorCount,
        droppedParents: dropped,
        failed: true,
      );
    } finally {
      for (final parent in parents) {
        parent.dispose();
      }
    }
  }

  /// Stores the parents of the wallet's transactions after a scan. [client]
  /// must be the one that scanned with prevouts: it answers from its cache.
  BdkElectrumCacheParents rememberParents(
    bdk.ElectrumClient client,
    bdk.Wallet wallet,
  ) {
    var stored = 0;
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
      final known = {
        for (final row in _db.select('SELECT txid FROM parent_transaction'))
          row['txid'] as String,
      };
      final missing = spent.difference(own).difference(known);
      if (missing.isEmpty) return (stored: 0, failed: false);

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
                stored++;
              }
            } finally {
              tx.dispose();
            }
          }
          _db.execute('COMMIT');
          return (stored: stored, failed: false);
        } catch (_) {
          _db.execute('ROLLBACK');
          rethrow;
        }
      } finally {
        insert.dispose();
      }
    } catch (_) {
      // The next scan downloads the parents again and retries.
      return (stored: 0, failed: true);
    }
  }

  void close() => _db.dispose();

  /// Adds to [parents] the stored parents whose bytes still hash to their
  /// txid, drops the others and returns how many were dropped.
  int _storedParents(List<bdk.Transaction> parents) {
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
    return corrupt.length;
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
