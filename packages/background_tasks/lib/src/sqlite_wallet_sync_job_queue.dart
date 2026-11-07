import 'dart:convert';
import 'dart:math';

import 'package:bull_logger/bull_logger.dart' show log;
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';

import 'background_task_logger.dart';

enum WalletSyncChain { bitcoin, liquid }

WalletSyncChain walletSyncChain(WalletKey key) => switch (key.network) {
  BitcoinNetwork() => WalletSyncChain.bitcoin,
  LiquidNetwork() => WalletSyncChain.liquid,
};

final class WalletSyncJobClaim {
  final String jobId;
  final WalletKey key;
  final String leaseToken;

  const WalletSyncJobClaim(this.jobId, this.key, this.leaseToken);
}

abstract interface class WalletSyncJobQueue {
  Duration get leaseDuration;
  Future<List<WalletSyncJobClaim>> reconcileAndClaim(
    Iterable<WalletRevision> jobs, {
    required WalletSyncChain chain,
    int maxJobs = 2,
    Iterable<WalletKey> excluding = const [],
    Iterable<WalletKey> unavailable = const [],
  });

  Future<bool> renew(WalletSyncJobClaim claim);
  Future<bool> completeSuccess(WalletSyncJobClaim claim);
  Future<bool> completeFailure(
    WalletSyncJobClaim claim, {
    required bool permanent,
    WalletRevision? failedRevision,
  });

  /// Gives back a claim that was never worked on: it is claimable again at
  /// once and its claim does not count as an attempt.
  Future<bool> release(WalletSyncJobClaim claim);
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
  final BackgroundTaskLogger _sink;
  bool _closed = false;

  factory SqliteWalletSyncJobQueue({
    String? databasePath,
    Database? database,
    DateTime Function()? clock,
    Duration leaseDuration = const Duration(minutes: 30),
    Duration retryBase = const Duration(minutes: 5),
    Duration retryMaximum = const Duration(hours: 6),
    BackgroundTaskLogger? logSink,
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
    BackgroundTaskLogger? logSink,
  }) : _database = _open(databasePath, database),
       _ownsDatabase = database == null,
       now = clock ?? _utcNow,
       _sink = logSink ?? LoggerBackgroundTaskLogger(log) {
    try {
      _database.execute('PRAGMA busy_timeout = 5000');
      _database.execute(
        '''CREATE TABLE IF NOT EXISTS wallet_sync_jobs (
        job_id TEXT PRIMARY KEY, chain TEXT NOT NULL, network TEXT NOT NULL,
        revision TEXT NOT NULL, inserted_at INTEGER NOT NULL,
        last_successful_at INTEGER, next_attempt_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0, permanent_failed INTEGER NOT NULL DEFAULT 0,
        lease_token TEXT, lease_expires_at INTEGER, absent INTEGER NOT NULL DEFAULT 0)''',
      );
    } catch (_) {
      if (_ownsDatabase) _database.dispose();
      rethrow;
    }
  }

  static Database _open(String? path, Database? database) {
    if (database != null) return database;
    if (path == null) {
      throw ArgumentError('Either a database path or a database is required');
    }
    return sqlite3.open(path);
  }

  static DateTime _utcNow() => DateTime.now().toUtc();

  @override
  Future<List<WalletSyncJobClaim>> reconcileAndClaim(
    Iterable<WalletRevision> jobs, {
    required WalletSyncChain chain,
    int maxJobs = 2,
    Iterable<WalletKey> excluding = const [],
    Iterable<WalletKey> unavailable = const [],
  }) async {
    _ensureOpen();
    if (maxJobs <= 0) throw ArgumentError.value(maxJobs, 'maxJobs');
    final current = jobs.where((j) => walletSyncChain(j.key) == chain).toList();
    final byId = {for (final job in current) _id(job.key): job.key};
    if (byId.length != current.length) {
      throw ArgumentError('Duplicate wallet synchronization jobs');
    }
    final unavailableIds = unavailable
        .where((key) => walletSyncChain(key) == chain)
        .map(_id)
        .toSet();
    final ids = <String>[...unavailableIds];
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
          permanent_failed=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.permanent_failed WHEN wallet_sync_jobs.revision = excluded.revision THEN wallet_sync_jobs.permanent_failed ELSE 0 END,
          attempts=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.attempts WHEN wallet_sync_jobs.revision = excluded.revision THEN wallet_sync_jobs.attempts ELSE 0 END,
          next_attempt_at=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.next_attempt_at WHEN wallet_sync_jobs.revision = excluded.revision THEN wallet_sync_jobs.next_attempt_at ELSE excluded.next_attempt_at END,
          lease_token=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.lease_token WHEN wallet_sync_jobs.revision = excluded.revision THEN wallet_sync_jobs.lease_token ELSE NULL END,
          lease_expires_at=CASE WHEN wallet_sync_jobs.lease_token IS NOT NULL AND wallet_sync_jobs.lease_expires_at > excluded.next_attempt_at THEN wallet_sync_jobs.lease_expires_at WHEN wallet_sync_jobs.revision = excluded.revision THEN wallet_sync_jobs.lease_expires_at ELSE NULL END,
          absent=0''',
          [
            id,
            chain.name,
            job.key.network.env.name,
            '${job.generation}:${job.revision}',
            insertionOrder++,
            timestamp,
          ],
        );
      }
      for (final id in unavailableIds) {
        // Presence must not reset a retry, replace a stamp or release a lease.
        _database.execute(
          'UPDATE wallet_sync_jobs SET absent = 0 WHERE job_id = ?',
          [id],
        );
      }
      final placeholders = ids.isEmpty
          ? ''
          : List.filled(ids.length, '?').join(',');
      final stale = ids.isEmpty
          ? _database.select(
              'SELECT job_id, lease_token, lease_expires_at FROM wallet_sync_jobs WHERE chain = ?',
              [chain.name],
            )
          : _database.select(
              'SELECT job_id, lease_token, lease_expires_at FROM wallet_sync_jobs WHERE chain = ? AND job_id NOT IN ($placeholders)',
              [chain.name, ...ids],
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
      final unavailablePlaceholders = List.filled(
        unavailableIds.length,
        '?',
      ).join(',');
      final readyOnly = unavailableIds.isEmpty
          ? ''
          : 'AND job_id NOT IN ($unavailablePlaceholders)';
      final eligibility =
          '''chain = ? AND absent = 0 AND permanent_failed = 0
        $readyOnly
        AND next_attempt_at <= ?
        AND (lease_expires_at IS NULL OR lease_expires_at <= ?)
        AND (last_successful_at IS NULL OR NOT EXISTS (
          SELECT 1 FROM wallet_sync_jobs unseen
          WHERE unseen.chain = ? AND unseen.absent = 0
            AND unseen.permanent_failed = 0
            $readyOnly
            AND unseen.next_attempt_at <= ?
            AND (unseen.lease_expires_at IS NULL OR unseen.lease_expires_at <= ?)
            AND unseen.last_successful_at IS NULL AND unseen.attempts = 0))''';
      final eligibleCount =
          _database.select(
                'SELECT COUNT(*) AS eligible_count FROM wallet_sync_jobs WHERE $eligibility',
                [
                  chain.name,
                  ...unavailableIds,
                  timestamp,
                  timestamp,
                  chain.name,
                  ...unavailableIds,
                  timestamp,
                  timestamp,
                ],
              ).single['eligible_count']
              as int;
      final excludedIds = [for (final key in excluding) _id(key)];
      final exclusion = excludedIds.isEmpty
          ? ''
          : 'AND job_id NOT IN (${List.filled(excludedIds.length, '?').join(',')})';
      // Oldest due time first: both overdue retries and successful wallets rotate.
      // Backoff prevents a repeatedly failing wallet from monopolizing work.
      final rows = _database.select(
        '''SELECT job_id, attempts FROM wallet_sync_jobs
        WHERE $eligibility $exclusion
        ORDER BY next_attempt_at, attempts,
          CASE WHEN last_successful_at IS NULL THEN 0 ELSE 1 END,
          last_successful_at, inserted_at, job_id LIMIT ?''',
        [
          chain.name,
          ...unavailableIds,
          timestamp,
          timestamp,
          chain.name,
          ...unavailableIds,
          timestamp,
          timestamp,
          ...excludedIds,
          maxJobs,
        ],
      );
      final claims = <WalletSyncJobClaim>[];
      for (final row in rows) {
        final jobId = row['job_id'] as String;
        final token = _token();
        // A claim counts as an attempt and schedules its own backoff, so a
        // worker killed before completing still backs its wallet off.
        final attempts = (row['attempts'] as int) + 1;
        _database.execute(
          'UPDATE wallet_sync_jobs SET lease_token = ?, lease_expires_at = ?, attempts = ?, next_attempt_at = ? WHERE job_id = ? AND (lease_expires_at IS NULL OR lease_expires_at <= ?)',
          [
            token,
            timestamp + leaseDuration.inMicroseconds,
            attempts,
            timestamp + _backoff(attempts).inMicroseconds,
            jobId,
            timestamp,
          ],
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
        BackgroundLogLevel.fine,
        'Wallet sync queue claim: chain=${chain.name} eligible=$eligibleCount claimed=${claims.length} max=$maxJobs',
      );
      return claims;
    } catch (_) {
      _rollback();
      rethrow;
    }
  }

  @override
  Future<bool> renew(WalletSyncJobClaim claim) async {
    _ensureOpen();
    _database.execute(
      'UPDATE wallet_sync_jobs SET lease_expires_at = ? WHERE job_id = ? AND lease_token = ?',
      [
        now().toUtc().add(leaseDuration).microsecondsSinceEpoch,
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
    WalletRevision? failedRevision,
  }) async {
    if (failedRevision != null && failedRevision.key != claim.key) {
      throw ArgumentError("Failure revision must belong to the claimed wallet");
    }
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
      // Counted by the claim; a failure only keeps the backoff.
      final attempts = max(1, rows.single['attempts'] as int);
      final delay = _backoff(attempts);
      _database.execute(
        'UPDATE wallet_sync_jobs SET revision = COALESCE(?, revision), attempts = ?, permanent_failed = ?, next_attempt_at = ?, lease_token = NULL, lease_expires_at = NULL WHERE job_id = ? AND lease_token = ?',
        [
          failedRevision == null
              ? null
              : '${failedRevision.generation}:${failedRevision.revision}',
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

  @override
  Future<bool> release(WalletSyncJobClaim claim) => _mutate(
    'UPDATE wallet_sync_jobs SET attempts = MAX(0, attempts - 1), next_attempt_at = ?, lease_token = NULL, lease_expires_at = NULL WHERE job_id = ? AND lease_token = ?',
    [now().toUtc().microsecondsSinceEpoch, claim.jobId, claim.leaseToken],
  );

  /// Doubles from [retryBase] per attempt, up to [retryMaximum].
  Duration _backoff(int attempts) {
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
    return Duration(microseconds: delayMicroseconds);
  }

  Future<bool> _mutate(String sql, List<Object?> args) async {
    _ensureOpen();
    _database.execute(sql, args);
    return _database.updatedRows == 1;
  }

  String _id(WalletKey key) => sha256
      .convert(
        utf8.encode(
          '${key.id}\u0000${walletSyncChain(key).name}\u0000${key.network.env.name}',
        ),
      )
      .toString();
  String _token() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Queue is closed');
  }

  void _rollback() {
    try {
      _database.execute('ROLLBACK');
    } catch (_) {}
  }

  void _safeLog(BackgroundLogLevel level, String message) {
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
