import 'dart:convert';
import 'dart:math';

import 'package:bull_logger/bull_logger.dart' show log;
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

enum WalletSyncLogLevel { config, fine, warning }

abstract interface class WalletSyncLogSink {
  void write(WalletSyncLogLevel level, String message);
}

final class BullLoggerWalletSyncLogSink implements WalletSyncLogSink {
  const BullLoggerWalletSyncLogSink();

  @override
  void write(WalletSyncLogLevel level, String message) {
    try {
      switch (level) {
        case WalletSyncLogLevel.config:
          log.config(message);
        case WalletSyncLogLevel.fine:
          log.fine(message);
        case WalletSyncLogLevel.warning:
          log.warning(message);
      }
    } catch (_) {}
  }
}

final class WalletSyncJobClaim {
  final String jobId;
  final WalletNetworkKey key;
  final String leaseToken;

  const WalletSyncJobClaim(this.jobId, this.key, this.leaseToken);
}

abstract interface class WalletSyncJobQueue {
  Duration get leaseDuration;
  Future<List<WalletSyncJobClaim>> reconcileAndClaim(
    Iterable<({WalletNetworkKey key, String revision})> jobs, {
    required String chain,
    int maxJobs = 2,
  });

  Future<bool> renew(WalletSyncJobClaim claim, {Duration? lease});
  Future<bool> completeSuccess(WalletSyncJobClaim claim);
  Future<bool> completeFailure(
    WalletSyncJobClaim claim, {
    required bool permanent,
  });
  Future<void> close();
}

/// SQLite-backed queue. The database contains no wallet identifiers, only
/// opaque SHA-256 job identities and scheduling state.
final class SqliteWalletSyncJobQueue implements WalletSyncJobQueue {
  final Database _database;
  final bool _ownsDatabase;
  final DateTime Function() now;
  @override
  final Duration leaseDuration;
  final Duration retryBase;
  final Duration retryMaximum;
  final WalletSyncLogSink _sink;
  bool _closed = false;

  factory SqliteWalletSyncJobQueue({
    String? databasePath,
    Database? database,
    DateTime Function()? clock,
    Duration leaseDuration = const Duration(minutes: 30),
    Duration retryBase = const Duration(minutes: 5),
    Duration retryMaximum = const Duration(hours: 6),
    WalletSyncLogSink? logSink,
  }) {
    if ((databasePath == null) == (database == null)) {
      throw ArgumentError('Provide exactly one of databasePath or database');
    }
    if (leaseDuration <= Duration.zero ||
        retryBase <= Duration.zero ||
        retryMaximum < retryBase) {
      throw ArgumentError(
        'Durations must be positive and retryMaximum >= retryBase',
      );
    }
    return SqliteWalletSyncJobQueue._internal(
      databasePath: databasePath,
      database: database,
      clock: clock,
      leaseDuration: leaseDuration,
      retryBase: retryBase,
      retryMaximum: retryMaximum,
      logSink: logSink,
    );
  }

  SqliteWalletSyncJobQueue._internal({
    String? databasePath,
    Database? database,
    DateTime Function()? clock,
    required this.leaseDuration,
    required this.retryBase,
    required this.retryMaximum,
    WalletSyncLogSink? logSink,
  }) : _database = _open(databasePath, database),
       _ownsDatabase = database == null,
       now = clock ?? _utcNow,
       _sink = logSink ?? const BullLoggerWalletSyncLogSink() {
    _database.execute('PRAGMA busy_timeout = 5000');
    _database.execute(
      '''CREATE TABLE IF NOT EXISTS wallet_sync_jobs (
      job_id TEXT PRIMARY KEY, chain TEXT NOT NULL, network TEXT NOT NULL,
      revision TEXT NOT NULL, pending_revision TEXT, inserted_at INTEGER NOT NULL,
      last_successful_at INTEGER, next_attempt_at INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0, permanent_failed INTEGER NOT NULL DEFAULT 0,
      lease_token TEXT, lease_expires_at INTEGER, absent INTEGER NOT NULL DEFAULT 0)''',
    );
  }

  static Database _open(String? path, Database? database) =>
      database ?? sqlite3.open(path!);
  static DateTime _utcNow() => DateTime.now().toUtc();

  @override
  Future<List<WalletSyncJobClaim>> reconcileAndClaim(
    Iterable<({WalletNetworkKey key, String revision})> jobs, {
    required String chain,
    int maxJobs = 2,
  }) async {
    _ensureOpen();
    if (maxJobs <= 0) throw ArgumentError.value(maxJobs, 'maxJobs');
    if (chain != 'bitcoin' && chain != 'liquid') {
      throw ArgumentError.value(chain, 'chain');
    }
    final current = jobs.where((j) => _normal(j.key.chain) == chain).toList();
    final byId = {for (final job in current) _id(job.key): job.key};
    if (byId.length != current.length) {
      throw ArgumentError('Duplicate wallet synchronization jobs');
    }
    if (current.any((job) => job.revision.trim().isEmpty)) {
      throw ArgumentError('Queue revisions must not be empty');
    }
    final ids = <String>[];
    final timestamp = now().toUtc().microsecondsSinceEpoch;
    _database.execute('BEGIN IMMEDIATE');
    try {
      final latestInsertion =
          _database
                  .select(
                    'SELECT MAX(inserted_at) AS latest_inserted_at FROM wallet_sync_jobs',
                  )
                  .single['latest_inserted_at']
              as int?;
      var insertionOrder = max(timestamp, (latestInsertion ?? 0) + 1);
      for (final job in current) {
        final id = _id(job.key);
        ids.add(id);
        _database.execute(
          '''INSERT INTO wallet_sync_jobs
          (job_id, chain, network, revision, inserted_at, next_attempt_at)
          VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(job_id) DO UPDATE SET
          chain=excluded.chain, network=excluded.network,
          revision=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.revision ELSE excluded.revision END,
          pending_revision=CASE
            WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at AND wallet_sync_jobs.revision <> excluded.revision THEN excluded.revision
            WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.pending_revision
            ELSE NULL END,
          permanent_failed=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.permanent_failed WHEN wallet_sync_jobs.revision = excluded.revision THEN wallet_sync_jobs.permanent_failed ELSE 0 END,
          attempts=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.attempts WHEN wallet_sync_jobs.revision = excluded.revision THEN wallet_sync_jobs.attempts ELSE 0 END,
          next_attempt_at=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.next_attempt_at WHEN wallet_sync_jobs.revision = excluded.revision THEN wallet_sync_jobs.next_attempt_at ELSE excluded.next_attempt_at END,
          lease_token=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.lease_token WHEN wallet_sync_jobs.revision = excluded.revision THEN wallet_sync_jobs.lease_token ELSE NULL END,
          lease_expires_at=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.lease_expires_at WHEN wallet_sync_jobs.revision = excluded.revision THEN wallet_sync_jobs.lease_expires_at ELSE NULL END,
          absent=0''',
          [
            id,
            chain,
            _normal(job.key.network),
            job.revision,
            insertionOrder++,
            timestamp,
          ],
        );
      }
      final placeholders = ids.isEmpty
          ? ''
          : List.filled(ids.length, '?').join(',');
      final stale = ids.isEmpty
          ? _database.select(
              'SELECT job_id, lease_token, lease_expires_at FROM wallet_sync_jobs WHERE chain = ?',
              [chain],
            )
          : _database.select(
              'SELECT job_id, lease_token, lease_expires_at FROM wallet_sync_jobs WHERE chain = ? AND job_id NOT IN ($placeholders)',
              [chain, ...ids],
            );
      for (final row in stale) {
        final jobId = row['job_id'] as String;
        final lease = row['lease_token'] as String?;
        final expiry = row['lease_expires_at'] as int?;
        if (lease != null && expiry != null && expiry > timestamp) {
          _database.execute(
            'UPDATE wallet_sync_jobs SET absent = 1 WHERE job_id = ?',
            [jobId],
          );
        } else {
          _database.execute('DELETE FROM wallet_sync_jobs WHERE job_id = ?', [
            jobId,
          ]);
        }
      }
      const eligibility = '''chain = ? AND absent = 0 AND permanent_failed = 0
        AND next_attempt_at <= ?
        AND (lease_expires_at IS NULL OR lease_expires_at <= ?)
        AND (last_successful_at IS NULL OR NOT EXISTS (
          SELECT 1 FROM wallet_sync_jobs unseen
          WHERE unseen.chain = ? AND unseen.absent = 0
            AND unseen.permanent_failed = 0
            AND unseen.next_attempt_at <= ?
            AND (unseen.lease_expires_at IS NULL OR unseen.lease_expires_at <= ?)
            AND unseen.last_successful_at IS NULL))''';
      final eligibleCount =
          _database.select(
                'SELECT COUNT(*) AS eligible_count FROM wallet_sync_jobs WHERE $eligibility',
                [chain, timestamp, timestamp, chain, timestamp, timestamp],
              ).single['eligible_count']
              as int;
      final rows = _database.select(
        '''SELECT job_id FROM wallet_sync_jobs
        WHERE $eligibility
        ORDER BY CASE WHEN last_successful_at IS NULL THEN 0 ELSE 1 END,
          last_successful_at, inserted_at, job_id LIMIT ?''',
        [chain, timestamp, timestamp, chain, timestamp, timestamp, maxJobs],
      );
      final claims = <WalletSyncJobClaim>[];
      for (final row in rows) {
        final jobId = row['job_id'] as String;
        final token = _token();
        _database.execute(
          'UPDATE wallet_sync_jobs SET lease_token = ?, lease_expires_at = ? WHERE job_id = ? AND (lease_expires_at IS NULL OR lease_expires_at <= ?)',
          [token, timestamp + leaseDuration.inMicroseconds, jobId, timestamp],
        );
        if (_database.updatedRows == 1) {
          final key = byId[jobId];
          if (key != null) {
            claims.add(WalletSyncJobClaim(jobId, key, token));
          }
        }
      }
      _database.execute('COMMIT');
      _safeLog(
        WalletSyncLogLevel.config,
        'Wallet sync queue claim: chain=$chain eligible=$eligibleCount claimed=${claims.length} max=$maxJobs',
      );
      return claims;
    } catch (_) {
      _rollback();
      rethrow;
    }
  }

  @override
  Future<bool> renew(WalletSyncJobClaim claim, {Duration? lease}) async {
    _ensureOpen();
    _database.execute(
      'UPDATE wallet_sync_jobs SET lease_expires_at = ? WHERE job_id = ? AND lease_token = ?',
      [
        now().toUtc().add(lease ?? leaseDuration).microsecondsSinceEpoch,
        claim.jobId,
        claim.leaseToken,
      ],
    );
    return _database.updatedRows == 1;
  }

  @override
  Future<bool> completeSuccess(WalletSyncJobClaim claim) async {
    final timestamp = now().toUtc().microsecondsSinceEpoch;
    final updated = await _mutate(
      'UPDATE wallet_sync_jobs SET last_successful_at = ?, next_attempt_at = ?, attempts = 0, permanent_failed = 0, lease_token = NULL, lease_expires_at = NULL WHERE job_id = ? AND lease_token = ?',
      [timestamp, timestamp, claim.jobId, claim.leaseToken],
    );
    if (updated) {
      _database.execute(
        'DELETE FROM wallet_sync_jobs WHERE job_id = ? AND absent = 1 AND lease_token IS NULL',
        [claim.jobId],
      );
    }
    return updated;
  }

  @override
  Future<bool> completeFailure(
    WalletSyncJobClaim claim, {
    required bool permanent,
  }) async {
    _ensureOpen();
    _database.execute('BEGIN IMMEDIATE');
    try {
      final rows = _database.select(
        'SELECT attempts FROM wallet_sync_jobs WHERE job_id = ? AND lease_token = ?',
        [claim.jobId, claim.leaseToken],
      );
      if (rows.length != 1) {
        _rollback();
        return false;
      }
      final attempts = (rows.single['attempts'] as int) + 1;
      var delayMicroseconds = retryBase.inMicroseconds;
      for (
        var retry = 1;
        retry < attempts && delayMicroseconds < retryMaximum.inMicroseconds;
        retry++
      ) {
        delayMicroseconds = min(
          retryMaximum.inMicroseconds,
          delayMicroseconds * 2,
        );
      }
      final delay = Duration(microseconds: delayMicroseconds);
      _database.execute(
        'UPDATE wallet_sync_jobs SET attempts = ?, permanent_failed = ?, next_attempt_at = ?, lease_token = NULL, lease_expires_at = NULL WHERE job_id = ? AND lease_token = ?',
        [
          attempts,
          permanent ? 1 : 0,
          now().toUtc().add(delay).microsecondsSinceEpoch,
          claim.jobId,
          claim.leaseToken,
        ],
      );
      final updated = _database.updatedRows == 1;
      if (updated) {
        _database.execute(
          'DELETE FROM wallet_sync_jobs WHERE job_id = ? AND absent = 1 AND lease_token IS NULL',
          [claim.jobId],
        );
      }
      _database.execute('COMMIT');
      return updated;
    } catch (_) {
      _rollback();
      rethrow;
    }
  }

  Future<bool> _mutate(String sql, List<Object?> args) async {
    _ensureOpen();
    _database.execute(sql, args);
    return _database.updatedRows == 1;
  }

  String _id(WalletNetworkKey key) => sha256
      .convert(
        utf8.encode(
          '${key.walletId}\u0000${_normal(key.chain)}\u0000${_normal(key.network)}',
        ),
      )
      .toString();
  String _token() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
  }

  String _normal(String value) => value.trim().toLowerCase();
  void _ensureOpen() {
    if (_closed) throw StateError('Queue is closed');
  }

  void _rollback() {
    try {
      _database.execute('ROLLBACK');
    } catch (_) {}
  }

  void _safeLog(WalletSyncLogLevel level, String message) {
    try {
      _sink.write(level, message);
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_ownsDatabase) _database.dispose();
  }
}
