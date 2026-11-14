import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bull_logger/bull_logger.dart' show log;
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';

import '../background_task_logger.dart';
import '../domain/background_tasks_failure.dart';
import '../domain/repositories/wallet_sync_job_queue_repository.dart';
import '../domain/wallet_sync_chain.dart';
import '../domain/wallet_sync_job_claim.dart';

/// SQLite-backed queue. The database contains no wallet identifiers, only
/// opaque SHA-256 job identities and scheduling state. The claim transaction
/// is [reconcileAndClaim].
final class SqliteWalletSyncJobQueueRepository
    implements WalletSyncJobQueueRepository {
  /// Unpublished: a single CREATE, no migration.
  static const schemaVersion = 1;

  final Database _database;
  final DateTime Function() now;
  @override
  final Duration leaseDuration;
  final Duration retryBase;
  final Duration retryMaximum;
  final BackgroundTaskLogger _sink;
  bool _closed = false;

  SqliteWalletSyncJobQueueRepository._(
    this._database, {
    DateTime Function()? clock,
    required this.leaseDuration,
    required this.retryBase,
    required this.retryMaximum,
    BackgroundTaskLogger? logSink,
  }) : now = clock ?? _utcNow,
       _sink = logSink ?? LoggerBackgroundTaskLogger(log) {
    if (leaseDuration <= Duration.zero ||
        retryBase <= Duration.zero ||
        retryMaximum < retryBase) {
      _database.dispose();
      throw ArgumentError(
        'Durations must be positive and retryMaximum >= retryBase',
      );
    }
  }

  /// Foreground only: creates the queue on first use, or checks its version.
  static Result<SqliteWalletSyncJobQueueRepository, BackgroundTasksFailure>
  openForeground(
    String path, {
    DateTime Function()? clock,
    Duration leaseDuration = const Duration(minutes: 30),
    Duration retryBase = const Duration(minutes: 5),
    Duration retryMaximum = const Duration(hours: 6),
    BackgroundTaskLogger? logSink,
  }) => _open(path, create: true).map(
    (database) => SqliteWalletSyncJobQueueRepository._(
      database,
      clock: clock,
      leaseDuration: leaseDuration,
      retryBase: retryBase,
      retryMaximum: retryMaximum,
      logSink: logSink,
    ),
  );

  /// Background: opens a queue the foreground created, never creating or
  /// migrating one. An absent, older or newer queue is refused.
  static Result<SqliteWalletSyncJobQueueRepository, BackgroundTasksFailure>
  openExisting(
    String path, {
    DateTime Function()? clock,
    Duration leaseDuration = const Duration(minutes: 30),
    Duration retryBase = const Duration(minutes: 5),
    Duration retryMaximum = const Duration(hours: 6),
    BackgroundTaskLogger? logSink,
  }) => _open(path, create: false).map(
    (database) => SqliteWalletSyncJobQueueRepository._(
      database,
      clock: clock,
      leaseDuration: leaseDuration,
      retryBase: retryBase,
      retryMaximum: retryMaximum,
      logSink: logSink,
    ),
  );

  static Result<Database, BackgroundTasksFailure> _open(
    String path, {
    required bool create,
  }) {
    final Database database;
    try {
      if (create) Directory(File(path).parent.path).createSync(recursive: true);
      // Without the create flag, opening a missing file fails here.
      database = sqlite3.open(
        path,
        mode: create ? OpenMode.readWriteCreate : OpenMode.readWrite,
      );
    } on Exception {
      return const Err(BackgroundTasksStoreUnavailableFailure());
    }
    try {
      database.execute('PRAGMA busy_timeout = 5000');
      database.execute('BEGIN IMMEDIATE');
      final version =
          database.select('PRAGMA user_version').single['user_version'] as int;
      final empty = database.select('SELECT 1 FROM sqlite_master').isEmpty;
      if (create && version == 0 && empty) {
        database.execute('''CREATE TABLE wallet_sync_jobs (
          job_id TEXT PRIMARY KEY, chain TEXT NOT NULL, network TEXT NOT NULL,
          revision TEXT NOT NULL, inserted_at INTEGER NOT NULL,
          last_successful_at INTEGER, next_attempt_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          permanent_failed INTEGER NOT NULL DEFAULT 0,
          lease_token TEXT, lease_expires_at INTEGER,
          absent INTEGER NOT NULL DEFAULT 0)''');
        database.execute('PRAGMA user_version = $schemaVersion');
      } else if (version != schemaVersion) {
        database.execute('ROLLBACK');
        database.dispose();
        return Err(BackgroundTasksStoreVersionFailure(version));
      }
      database.execute('COMMIT');
      return Ok(database);
    } on SqliteException {
      _rollbackOf(database);
      database.dispose();
      return const Err(BackgroundTasksStorageFailure());
    }
  }

  static DateTime _utcNow() => DateTime.now().toUtc();

  @override
  Future<Result<List<WalletSyncJobClaim>, BackgroundTasksFailure>>
  reconcileAndClaim(
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
    try {
      _database.execute('BEGIN IMMEDIATE');
    } on SqliteException {
      return const Err(BackgroundTasksStorageFailure());
    }
    try {
      // 1. Record the catalog: every current job, with its stamp.
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
        final revision = '${job.generation}:${job.revision}';
        ids.add(id);
        _database.execute(
          '''INSERT INTO wallet_sync_jobs
          (job_id, chain, network, revision, inserted_at, next_attempt_at)
          VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(job_id) DO UPDATE SET
          chain = excluded.chain, network = excluded.network, absent = 0''',
          [
            id,
            chain.name,
            job.key.network.env.name,
            revision,
            insertionOrder++,
            timestamp,
          ],
        );
        // A new stamp re-enables the job with a clean retry state, unless a
        // live lease still works on it: that run settles the old stamp.
        _database.execute(
          '''UPDATE wallet_sync_jobs SET revision = ?, permanent_failed = 0,
          attempts = 0, next_attempt_at = ?, lease_token = NULL,
          lease_expires_at = NULL
          WHERE job_id = ? AND revision <> ?
            AND (lease_token IS NOT NULL AND lease_expires_at > ?) IS NOT 1''',
          [revision, timestamp, id, revision, timestamp],
        );
      }
      for (final id in unavailableIds) {
        // Presence must not reset a retry, replace a stamp or release a lease.
        _database.execute(
          'UPDATE wallet_sync_jobs SET absent = 0 WHERE job_id = ?',
          [id],
        );
      }
      // 2. Forget wallets that left the catalog, unless a live lease runs.
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
      // 3. Claim the due jobs, oldest due time first.
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
      final eligibilityArgs = [
        chain.name,
        ...unavailableIds,
        timestamp,
        timestamp,
        chain.name,
        ...unavailableIds,
        timestamp,
        timestamp,
      ];
      final eligibleCount =
          _database
                  .select(
                    'SELECT COUNT(*) AS eligible_count FROM wallet_sync_jobs WHERE $eligibility',
                    eligibilityArgs,
                  )
                  .single['eligible_count']
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
        [...eligibilityArgs, ...excludedIds, maxJobs],
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
      return Ok(List.unmodifiable(claims));
    } on SqliteException {
      _rollbackOf(_database);
      return const Err(BackgroundTasksStorageFailure());
    } catch (_) {
      _rollbackOf(_database);
      rethrow;
    }
  }

  @override
  Future<Result<void, BackgroundTasksFailure>> renew(
    WalletSyncJobClaim claim,
  ) async => _byLease(
    'UPDATE wallet_sync_jobs SET lease_expires_at = ? WHERE job_id = ? AND lease_token = ?',
    [
      now().toUtc().add(leaseDuration).microsecondsSinceEpoch,
      claim.jobId,
      claim.leaseToken,
    ],
  );

  @override
  Future<Result<void, BackgroundTasksFailure>> completeSuccess(
    WalletSyncJobClaim claim,
  ) async {
    final timestamp = now().toUtc().microsecondsSinceEpoch;
    final updated = _byLease(
      'UPDATE wallet_sync_jobs SET last_successful_at = ?, next_attempt_at = ?, attempts = 0, permanent_failed = 0, lease_token = NULL, lease_expires_at = NULL WHERE job_id = ? AND lease_token = ?',
      [timestamp, timestamp, claim.jobId, claim.leaseToken],
    );
    if (updated case Err()) return updated;
    return _deleteIfAbsent(claim);
  }

  @override
  Future<Result<void, BackgroundTasksFailure>> completeFailure(
    WalletSyncJobClaim claim, {
    required bool permanent,
    WalletRevision? failedRevision,
  }) async {
    if (failedRevision != null && failedRevision.key != claim.key) {
      throw ArgumentError("Failure revision must belong to the claimed wallet");
    }
    _ensureOpen();
    try {
      _database.execute('BEGIN IMMEDIATE');
      final rows = _database.select(
        'SELECT attempts FROM wallet_sync_jobs WHERE job_id = ? AND lease_token = ?',
        [claim.jobId, claim.leaseToken],
      );
      if (rows.length != 1) {
        _rollbackOf(_database);
        return const Err(BackgroundTasksClaimLostFailure());
      }
      // Counted by the claim; a failure only keeps the backoff.
      final attempts = max(1, rows.single['attempts'] as int);
      _database.execute(
        'UPDATE wallet_sync_jobs SET revision = COALESCE(?, revision), attempts = ?, permanent_failed = ?, next_attempt_at = ?, lease_token = NULL, lease_expires_at = NULL WHERE job_id = ? AND lease_token = ?',
        [
          failedRevision == null
              ? null
              : '${failedRevision.generation}:${failedRevision.revision}',
          attempts,
          permanent ? 1 : 0,
          now().toUtc().add(_backoff(attempts)).microsecondsSinceEpoch,
          claim.jobId,
          claim.leaseToken,
        ],
      );
      _database.execute(
        'DELETE FROM wallet_sync_jobs WHERE job_id = ? AND absent = 1 AND lease_token IS NULL',
        [claim.jobId],
      );
      _database.execute('COMMIT');
      return const Ok(null);
    } on SqliteException {
      _rollbackOf(_database);
      return const Err(BackgroundTasksStorageFailure());
    }
  }

  @override
  Future<Result<void, BackgroundTasksFailure>> release(
    WalletSyncJobClaim claim,
  ) async => _byLease(
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

  /// One update guarded by the lease token: no row means the claim was lost.
  Result<void, BackgroundTasksFailure> _byLease(
    String sql,
    List<Object?> args,
  ) {
    _ensureOpen();
    try {
      _database.execute(sql, args);
      return _database.updatedRows == 1
          ? const Ok(null)
          : const Err(BackgroundTasksClaimLostFailure());
    } on SqliteException {
      return const Err(BackgroundTasksStorageFailure());
    }
  }

  /// A wallet that left the catalog while leased goes once its lease ends.
  Result<void, BackgroundTasksFailure> _deleteIfAbsent(
    WalletSyncJobClaim claim,
  ) {
    try {
      _database.execute(
        'DELETE FROM wallet_sync_jobs WHERE job_id = ? AND absent = 1 AND lease_token IS NULL',
        [claim.jobId],
      );
      return const Ok(null);
    } on SqliteException {
      return const Err(BackgroundTasksStorageFailure());
    }
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

  static void _rollbackOf(Database database) {
    try {
      database.execute('ROLLBACK');
    } on SqliteException {
      // Nothing is open.
    }
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
    _database.dispose();
  }
}

/// Phase A contact: lib/features/wallet still opens the queue through this
/// name, creating it like [SqliteWalletSyncJobQueueRepository.openForeground].
/// Phase B moves the feature to the two named openings and deletes this class.
final class SqliteWalletSyncJobQueue
    extends SqliteWalletSyncJobQueueRepository {
  SqliteWalletSyncJobQueue({required String databasePath})
    : super._(
        switch (SqliteWalletSyncJobQueueRepository._open(
          databasePath,
          create: true,
        )) {
          Ok(:final value) => value,
          Err() => throw const _QueueUnavailable(),
        },
        leaseDuration: const Duration(minutes: 30),
        retryBase: const Duration(minutes: 5),
        retryMaximum: const Duration(hours: 6),
      );
}

final class _QueueUnavailable implements Exception {
  const _QueueUnavailable();
}
