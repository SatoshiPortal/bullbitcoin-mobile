import 'dart:math';
import '../domain/entities/attempt_alert.dart';
import '../domain/entities/attempt_monitoring_snapshot.dart';
export '../domain/entities/attempt_monitoring_snapshot.dart';
export '../domain/repositories/recoverbull_attempt_monitoring_repository.dart';
import 'dart:async';
import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart' show sha256;

import 'package:convert/convert.dart' as convert;
import 'package:drift/drift.dart';
import 'package:recoverbull/recoverbull.dart';

import '../database/recoverbull_database.dart';
import '../domain/entities/attempt_monitoring_state.dart';
import '../domain/entities/drive_backup_cache_entry.dart';
import '../domain/entities/key_server_attempts.dart';
import '../domain/entities/monitored_backup.dart';

final class RecoverBullAttemptMonitoringStore {
  static Future<void> _writeTail = Future<void>.value();
  final RecoverBullDatabase database;
  final Map<int, _OwnOperation> _ownOperations = {};
  final Map<String, int> _ownActivityRevisions = {};
  final Map<String, Map<int, Set<String>>> _ownCandidates = {};
  final List<int> _candidateSalt = List.generate(
    32,
    (_) => Random.secure().nextInt(256),
  );
  int _nextOwnOperation = 0;
  int? _ownGeneration;
  bool _monitoringClosed = false;

  RecoverBullAttemptMonitoringStore(this.database);

  Future<RecoverBullOwnAttemptOperation?> beginOwnOperation(
    List<int> identifier, {
    required String password,
    required DateTime now,
  }) async {
    if (_monitoringClosed) return null;
    return database.transaction(() async {
      final current = await state();
      _syncOwnGeneration(current.generation);
      if (!current.attemptMonitoringEnabled ||
          _monitoringClosed ||
          _ownOperations.length >= 128) {
        return null;
      }
      final digest = _hex(_digest(identifier));
      final operation = RecoverBullOwnAttemptOperation(
        id: ++_nextOwnOperation,
        generation: current.generation,
        backupDigest: digest,
      );
      final candidate = sha256.convert([
        ..._candidateSalt,
        ...utf8.encode(password),
      ]).toString();
      _ownOperations[operation.id] = _OwnOperation(
        operation,
        candidate,
        attemptWindowIdentity(now),
      );
      _ownActivityRevisions[digest] = (_ownActivityRevisions[digest] ?? 0) + 1;
      return operation;
    });
  }

  Future<bool> isOwnOperationCurrent(
    RecoverBullOwnAttemptOperation operation,
  ) async {
    if (_monitoringClosed ||
        !identical(_ownOperations[operation.id]?.operation, operation)) {
      return false;
    }
    final current = await state();
    return current.attemptMonitoringEnabled &&
        current.generation == operation.generation;
  }

  Future<void> endOwnOperation(RecoverBullOwnAttemptOperation operation) async {
    if (!identical(_ownOperations[operation.id]?.operation, operation)) return;
    _ownOperations.remove(operation.id);
    _ownActivityRevisions[operation.backupDigest] =
        (_ownActivityRevisions[operation.backupDigest] ?? 0) + 1;
  }

  Future<void> cancelOwnOperations() async {
    _monitoringClosed = true;
    _clearOwnOperations();
  }

  void _clearOwnOperations() {
    _ownOperations.clear();
    _ownCandidates.clear();
    _ownActivityRevisions.clear();
  }

  void _syncOwnGeneration(int generation) {
    if (_ownGeneration == generation) return;
    _clearOwnOperations();
    _ownGeneration = generation;
  }

  bool _ownActivityChanged(
    RecoverBullAttemptMonitoringSnapshotToken token,
    List<int> digest,
  ) {
    final hash = _hex(digest);
    return (token.ownActivityRevisions[hash] ?? 0) !=
            (_ownActivityRevisions[hash] ?? 0) ||
        _ownOperations.values.any(
          (pending) => pending.operation.backupDigest == hash,
        );
  }

  Future<SuspiciousActivityAlert?> completeOwnOperation(
    RecoverBullOwnAttemptOperation operation, {
    required bool counted,
    KeyServerAttemptStatus? status,
    RecoverBullAttemptsSnapshot? snapshot,
  }) async {
    final pending = _ownOperations[operation.id];
    if (_monitoringClosed ||
        pending == null ||
        !identical(pending.operation, operation)) {
      return null;
    }
    try {
      if (!counted) return null;
      return await database.transaction(() async {
        final current = await state();
        if (!current.attemptMonitoringEnabled ||
            current.generation != operation.generation ||
            _monitoringClosed) {
          return null;
        }
        final digest = Uint8List.fromList(_decodeHash(operation.backupDigest));
        final row = await _row(digest);
        final observed =
            status?.totalAttempts ??
            (snapshot == null ? null : _observed(snapshot, digest));
        final observedAt =
            status?.windowStartedAt ??
            snapshot?.windowStartedAt.entries
                .where((entry) => _same(entry.key, digest))
                .map((entry) => entry.value)
                .firstOrNull ??
            snapshot?.collectionStartedAt;
        final window = observedAt == null
            ? (row != null && row.currentWindow != 0
                  ? row.currentWindow
                  : pending.window)
            : attemptWindowIdentity(observedAt);
        // Older inline responses cannot replace a newer window's baseline.
        if (row != null && row.currentWindow > window) return null;
        var windows = _ownCandidates[operation.backupDigest];
        if (windows == null && _ownCandidates.length < 256) {
          windows = <int, Set<String>>{};
          _ownCandidates[operation.backupDigest] = windows;
        }
        windows?.removeWhere((key, _) => key != window);
        final candidates = windows?.putIfAbsent(window, () => <String>{});
        // Once bounded memory is full, attribution is unproven. Never
        // repeatedly credit a candidate that cannot be remembered.
        final ownNewCandidate =
            candidates != null &&
            candidates.length < 32 &&
            !candidates.contains(pending.candidate);
        if (ownNewCandidate) candidates.add(pending.candidate);
        if (row == null ||
            (row.currentWindow == 0 && row.lastWarningWindow == 0)) {
          await database
              .into(database.recoverbullMonitoredBackup)
              .insertOnConflictUpdate(
                RecoverbullMonitoredBackupCompanion.insert(
                  digest: digest,
                  origin: const Value('adopted'),
                  expectedServerDistinctCandidateTotal: Value(observed ?? 0),
                  currentWindow: Value(observed == null ? 0 : window),
                  lastWarningWindow: Value(observed == null ? 0 : window),
                  rowRevision: Value((row?.rowRevision ?? -1) + 1),
                ),
              );
          return null;
        }
        final anchor = row.currentWindow == window
            ? row.expectedServerDistinctCandidateTotal
            : 0;
        final ownCredit =
            ownNewCandidate && (observed == null || observed > anchor) ? 1 : 0;
        final expected = anchor + ownCredit;
        final anotherPending = _ownOperations.values.any(
          (other) =>
              other.operation.id != operation.id &&
              other.operation.backupDigest == operation.backupDigest,
        );
        final suspicious =
            !anotherPending && observed != null && observed > expected;
        await (database.update(database.recoverbullMonitoredBackup)..where(
              (entry) =>
                  entry.digest.equals(digest) &
                  entry.rowRevision.equals(row.rowRevision),
            ))
            .write(
              RecoverbullMonitoredBackupCompanion(
                expectedServerDistinctCandidateTotal: Value(expected),
                currentWindow: Value(window),
                lastWarningWindow: suspicious
                    ? Value(window)
                    : const Value.absent(),
                rowRevision: Value(row.rowRevision + 1),
              ),
            );
        if (!suspicious) return null;
        return SuspiciousActivityAlert(
          backupIdHash: operation.backupDigest,
          observedTotal: observed,
          expectedTotal: expected,
          windowStartedAt: DateTime.fromMillisecondsSinceEpoch(
            window * 1000,
            isUtc: true,
          ),
        );
      });
    } finally {
      await endOwnOperation(operation);
    }
  }

  Future<List<MonitoredBackup>> monitoredBackups() async => [
    for (final row
        in await database.select(database.recoverbullMonitoredBackup).get())
      _monitoredBackup(row),
  ];

  Future<AttemptMonitoringState> state() async =>
      _state(await database.select(database.recoverbullState).getSingle());

  Future<void> replaceBackup(
    AttemptMonitoringBackupState value, {
    RecoverBullAttemptMonitoringSnapshotToken? token,
  }) async {
    final digest = Uint8List.fromList(_decodeHash(value.backupIdHash));
    await _serializeWrite(() async {
      for (var attempt = 0; attempt < 3; attempt++) {
        final changed = await database.transaction(() async {
          if (!(await state()).attemptMonitoringEnabled) return true;
          if (token != null && !await _isTokenCurrent(token)) return true;
          final row = await _row(digest);
          if (token != null &&
              !_rowTokenMatches(token, digest, row?.rowRevision)) {
            return true;
          }
          if (row == null) {
            await database
                .into(database.recoverbullMonitoredBackup)
                .insert(
                  RecoverbullMonitoredBackupCompanion.insert(
                    digest: digest,
                    expectedServerDistinctCandidateTotal: Value(
                      value.expectedTotalAttempts,
                    ),
                    currentWindow: Value(value.currentWindow ?? 0),
                    lastWarningWindow: Value(value.lastWarningWindow),
                  ),
                );
            return true;
          }
          return await (database.update(database.recoverbullMonitoredBackup)
                    ..where(
                      (t) =>
                          t.digest.equals(digest) &
                          t.rowRevision.equals(row.rowRevision),
                    ))
                  .write(
                    RecoverbullMonitoredBackupCompanion(
                      expectedServerDistinctCandidateTotal: Value(
                        value.expectedTotalAttempts,
                      ),
                      currentWindow: Value(value.currentWindow ?? 0),
                      lastWarningWindow: Value(value.lastWarningWindow),
                      rowRevision: Value(row.rowRevision + 1),
                    ),
                  ) ==
              1;
        });
        if (changed) return;
      }
      throw Exception(
        'could not replace monitored backup without a stale revision',
      );
    });
  }

  Future<bool> isMonitored(List<int> identifier) async =>
      await _row(_digest(identifier)) != null;

  Future<void> removeBackup(String backupIdHex) async {
    final digest = _digest(_decodeHash(backupIdHex));
    await (database.delete(
      database.recoverbullMonitoredBackup,
    )..where((row) => row.digest.equals(digest))).go();
  }

  List<int> digestFor(List<int> identifier) => _digest(identifier);

  Future<void> registerBackup(
    List<int> identifier, {
    MonitoredBackupOrigin origin = MonitoredBackupOrigin.created,
    int observedTotal = 0,
    int window = 0,
    RecoverBullAttemptMonitoringSnapshotToken? token,
    String? driveAccount,
    String? driveFileId,
    DateTime? driveFileCreatedAt,
    DateTime? driveFileModifiedAt,
  }) async {
    if (observedTotal < 0) throw ArgumentError.value(observedTotal);
    if (window < 0) throw ArgumentError.value(window);
    final digest = _digest(identifier);
    final adopted = origin != MonitoredBackupOrigin.created;
    await database.transaction(() async {
      if (!(await state()).attemptMonitoringEnabled) return;
      if (token != null && !await _isTokenCurrent(token)) return;
      await database
          .into(database.recoverbullMonitoredBackup)
          .insert(
            RecoverbullMonitoredBackupCompanion.insert(
              digest: digest,
              expectedServerDistinctCandidateTotal: Value(
                adopted ? observedTotal : 0,
              ),
              currentWindow: Value(adopted ? window : 0),
              lastWarningWindow: adopted ? Value(window) : const Value(null),
              origin: Value(
                _originColumn(
                  adopted
                      ? (driveAccount != null
                            ? MonitoredBackupOrigin.drive
                            : MonitoredBackupOrigin.adopted)
                      : MonitoredBackupOrigin.created,
                ),
              ),
              driveAccountHash: Value(
                driveAccount == null ? null : _accountHash(driveAccount),
              ),
              driveFileId: Value(driveFileId),
              driveFileCreatedAt: Value(driveFileCreatedAt),
              driveFileModifiedAt: Value(driveFileModifiedAt),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    });
  }

  Future<void> purgeDriveAccount(String account) async {
    final accountHash = _accountHash(account);
    await (database.delete(
      database.recoverbullMonitoredBackup,
    )..where((row) => row.driveAccountHash.equals(accountHash))).go();
    await (database.delete(
      database.recoverbullDriveBackupCache,
    )..where((row) => row.accountHash.equals(accountHash))).go();
  }

  Future<List<MonitoredBackup>> driveBackups(String account) async => [
    for (final row
        in await (database.select(database.recoverbullMonitoredBackup)..where(
              (row) => row.driveAccountHash.equals(_accountHash(account)),
            ))
            .get())
      _monitoredBackup(row),
  ];

  Future<List<DriveBackupCacheEntry>> driveCache(String account) async => [
    for (final row in await (database.select(
      database.recoverbullDriveBackupCache,
    )..where((row) => row.accountHash.equals(_accountHash(account)))).get())
      _driveCacheEntry(row),
  ];

  Future<void> saveDriveCache({
    required String account,
    required String driveFileId,
    required List<int> backupDigest,
    required DateTime createdAt,
    DateTime? modifiedAt,
  }) async {
    await database
        .into(database.recoverbullDriveBackupCache)
        .insertOnConflictUpdate(
          RecoverbullDriveBackupCacheCompanion.insert(
            accountHash: _accountHash(account),
            driveFileId: driveFileId,
            backupDigest: Uint8List.fromList(backupDigest),
            driveFileCreatedAt: createdAt,
            driveFileModifiedAt: Value(modifiedAt),
          ),
        );
  }

  /// Reconciles the complete Drive view in one transaction. A local row is
  /// never converted into a Drive row, but a Drive row can be re-adopted after
  /// monitoring was disabled because its cache entry is not authoritative.
  ///
  /// Monitoring follows a single Google account, the one signed in now: the
  /// Drive rows and cache entries of any other account are purged here by
  /// design, so switching accounts stops monitoring the previous account's
  /// backups until it is signed in again.
  Future<bool> reconcileDriveBackups(
    String account,
    List<DriveBackupObservation> observations,
  ) async {
    return database.transaction<bool>(() async {
      final enabled =
          await (database.select(database.recoverbullState)
                ..where((row) => row.id.equals(1)))
              .getSingle()
              .then((row) => row.attemptMonitoringEnabled);
      if (!enabled) return false;
      final accountHash = _accountHash(account);
      await (database.delete(database.recoverbullMonitoredBackup)..where(
            (row) =>
                row.driveAccountHash.isNotNull() &
                row.driveAccountHash.isNotValue(accountHash),
          ))
          .go();
      await (database.delete(
        database.recoverbullDriveBackupCache,
      )..where((row) => row.accountHash.isNotValue(accountHash))).go();
      final desired = {for (final item in observations) item.digestKey};
      final rows = await driveBackups(account);
      for (final row in rows) {
        if (!desired.contains(_hex(row.digest))) {
          final digest = Uint8List.fromList(row.digest);
          await (database.delete(
            database.recoverbullMonitoredBackup,
          )..where((t) => t.digest.equals(digest))).go();
        }
      }
      final caches = await driveCache(account);
      final currentFiles = {for (final item in observations) item.fileId};
      for (final cache in caches) {
        if (!currentFiles.contains(cache.driveFileId)) {
          await (database.delete(database.recoverbullDriveBackupCache)..where(
                (t) =>
                    t.accountHash.equals(accountHash) &
                    t.driveFileId.equals(cache.driveFileId),
              ))
              .go();
        }
      }
      for (final item in observations) {
        final digest = Uint8List.fromList(item.digest);
        final existing = await (database.select(
          database.recoverbullMonitoredBackup,
        )..where((t) => t.digest.equals(digest))).getSingleOrNull();
        if (existing == null) {
          await database
              .into(database.recoverbullMonitoredBackup)
              .insert(
                RecoverbullMonitoredBackupCompanion.insert(
                  digest: digest,
                  lastWarningWindow: const Value(0),
                  origin: Value(_originColumn(MonitoredBackupOrigin.drive)),
                  driveAccountHash: Value(accountHash),
                  driveFileId: Value(item.fileId),
                  driveFileCreatedAt: Value(item.createdAt),
                  driveFileModifiedAt: Value(item.modifiedAt),
                ),
              );
        } else if (existing.origin ==
            _originColumn(MonitoredBackupOrigin.drive)) {
          await (database.update(
            database.recoverbullMonitoredBackup,
          )..where((t) => t.digest.equals(digest))).write(
            RecoverbullMonitoredBackupCompanion(
              driveAccountHash: Value(accountHash),
              driveFileId: Value(item.fileId),
              driveFileCreatedAt: Value(item.createdAt),
              driveFileModifiedAt: Value(item.modifiedAt),
            ),
          );
        }
        await database
            .into(database.recoverbullDriveBackupCache)
            .insertOnConflictUpdate(
              RecoverbullDriveBackupCacheCompanion.insert(
                accountHash: accountHash,
                driveFileId: item.fileId,
                backupDigest: digest,
                driveFileCreatedAt: item.createdAt,
                driveFileModifiedAt: Value(item.modifiedAt),
              ),
            );
      }
      return true;
    });
  }

  Future<void> recordStatus(
    List<int> identifier,
    KeyServerAttemptStatus status,
  ) async {
    final digest = _digest(identifier);
    final window = attemptWindowIdentity(status.windowStartedAt);
    await _serializeWrite(() async {
      for (var attempt = 0; attempt < 3; attempt++) {
        final changed = await database.transaction(() async {
          final row = await _row(digest);
          if (row == null) return true;
          return await (database.update(database.recoverbullMonitoredBackup)
                    ..where(
                      (t) =>
                          t.digest.equals(digest) &
                          t.rowRevision.equals(row.rowRevision),
                    ))
                  .write(
                    RecoverbullMonitoredBackupCompanion(
                      expectedServerDistinctCandidateTotal: Value(
                        status.totalAttempts,
                      ),
                      currentWindow: Value(window),
                      rowRevision: Value(row.rowRevision + 1),
                    ),
                  ) ==
              1;
        });
        if (changed) return;
      }
      throw Exception(
        'could not record attempt status without a stale revision',
      );
    });
  }

  Future<void> recordOwnAttempt(
    List<int> identifier, {
    required int serverTotalAttempts,
    required DateTime window,
  }) async {
    if (serverTotalAttempts < 0) throw ArgumentError.value(serverTotalAttempts);
    final digest = _digest(identifier);
    await _serializeWrite(() async {
      Object? failure;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await database.transaction(() async {
            final row = await _row(digest);
            if (row == null) return;
            await (database.update(database.recoverbullMonitoredBackup)..where(
                  (t) =>
                      t.digest.equals(digest) &
                      t.rowRevision.equals(row.rowRevision),
                ))
                .write(
                  RecoverbullMonitoredBackupCompanion(
                    expectedServerDistinctCandidateTotal: Value(
                      serverTotalAttempts,
                    ),
                    currentWindow: Value(_window(window)),
                    rowRevision: Value(row.rowRevision + 1),
                  ),
                );
          });
          return;
        } on Exception catch (error) {
          failure = error;
          if (!error.toString().contains('database is locked') ||
              attempt == 2) {
            rethrow;
          }
          await Future<void>.delayed(
            Duration(milliseconds: const [100, 300, 700][attempt]),
          );
        }
      }
      if (failure != null) throw failure;
    });
  }

  Future<T> _serializeWrite<T>(Future<T> Function() action) {
    final previous = _writeTail;
    final done = Completer<void>();
    _writeTail = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }

  Future<RecoverBullAttemptMonitoringSnapshotToken> captureToken() async {
    return database.transaction(() async {
      final state = await database
          .select(database.recoverbullState)
          .getSingle();
      _syncOwnGeneration(state.generation);
      final rows = await database
          .select(database.recoverbullMonitoredBackup)
          .get();
      return RecoverBullAttemptMonitoringSnapshotToken(
        generation: state.generation,
        stateRevision: state.revision,
        etag: state.etag,
        ownActivityRevisions: Map.unmodifiable(_ownActivityRevisions),
        rowRevisions: {
          for (final row in rows)
            Uint8List.fromList(row.digest): row.rowRevision,
        },
      );
    });
  }

  Future<RecoverBullAttemptMonitoringApplyResult> applySnapshot(
    RecoverBullAttemptsSnapshot snapshot, [
    RecoverBullAttemptMonitoringSnapshotToken? token,
  ]) async {
    if (_monitoringClosed) {
      return const RecoverBullAttemptMonitoringApplyResult(false, 0);
    }
    final resolvedToken = token ?? await captureToken();
    return database.transaction(() async {
      if (_monitoringClosed) {
        return const RecoverBullAttemptMonitoringApplyResult(false, 0);
      }
      final state = await database
          .select(database.recoverbullState)
          .getSingle();
      if (state.generation != resolvedToken.generation ||
          state.revision != resolvedToken.stateRevision) {
        return const RecoverBullAttemptMonitoringApplyResult(false, 0);
      }
      var conflicts = 0;
      final eligibleDigests = <String>{};
      final alerts = <SuspiciousActivityAlert>[];
      final rows = await database
          .select(database.recoverbullMonitoredBackup)
          .get();
      for (final row in rows) {
        if (_ownActivityChanged(resolvedToken, row.digest)) {
          conflicts++;
          continue;
        }
        final revision = resolvedToken.rowRevisions.entries
            .where((entry) => _same(entry.key, row.digest))
            .map((entry) => entry.value)
            .firstOrNull;
        if (revision == null || revision != row.rowRevision) {
          conflicts++;
          final window = _window(
            snapshot.windowStartedAt.entries
                    .where((entry) => _same(entry.key, row.digest))
                    .map((entry) => entry.value)
                    .firstOrNull ??
                snapshot.collectionStartedAt,
          );
          if (row.currentWindow == window &&
              !(row.currentWindow == 0 && row.lastWarningWindow == 0)) {
            eligibleDigests.add(_hex(row.digest));
            final observed = _observed(snapshot, row.digest);
            if (observed != null &&
                observed > row.expectedServerDistinctCandidateTotal) {
              alerts.add(_snapshotAlert(row, observed, window));
            }
          }
          continue;
        }
        final observed = _observed(snapshot, row.digest);
        if (observed == null || observed < 0) {
          continue;
        }
        final observedWindow = _window(
          snapshot.windowStartedAt.entries
                  .where((entry) => _same(entry.key, row.digest))
                  .map((entry) => entry.value)
                  .firstOrNull ??
              snapshot.collectionStartedAt,
        );
        if (row.currentWindow == 0 && row.lastWarningWindow == 0) {
          await (database.update(database.recoverbullMonitoredBackup)..where(
                (t) =>
                    t.digest.equals(row.digest) &
                    t.rowRevision.equals(row.rowRevision),
              ))
              .write(
                RecoverbullMonitoredBackupCompanion(
                  expectedServerDistinctCandidateTotal: Value(observed),
                  currentWindow: Value(observedWindow),
                  lastWarningWindow: const Value(null),
                  rowRevision: Value(row.rowRevision + 1),
                ),
              );
          continue;
        }
        if (row.currentWindow != 0 && row.currentWindow != observedWindow) {
          await (database.update(database.recoverbullMonitoredBackup)..where(
                (t) =>
                    t.digest.equals(row.digest) &
                    t.rowRevision.equals(row.rowRevision),
              ))
              .write(
                RecoverbullMonitoredBackupCompanion(
                  expectedServerDistinctCandidateTotal: const Value(0),
                  currentWindow: Value(observedWindow),
                  lastWarningWindow: observed > 0
                      ? Value(observedWindow)
                      : const Value(null),
                  rowRevision: Value(row.rowRevision + 1),
                ),
              );
          if (observed > 0) {
            alerts.add(
              SuspiciousActivityAlert(
                backupIdHash: _hex(row.digest),
                observedTotal: observed,
                expectedTotal: 0,
                windowStartedAt: DateTime.fromMillisecondsSinceEpoch(
                  observedWindow * 1000,
                  isUtc: true,
                ),
              ),
            );
          }
          continue;
        }
        eligibleDigests.add(_hex(row.digest));
        if (observed <= row.expectedServerDistinctCandidateTotal) continue;
        alerts.add(_snapshotAlert(row, observed, observedWindow));
        await (database.update(database.recoverbullMonitoredBackup)..where(
              (t) =>
                  t.digest.equals(row.digest) &
                  t.rowRevision.equals(row.rowRevision),
            ))
            .write(
              RecoverbullMonitoredBackupCompanion(
                lastWarningWindow: Value(observedWindow),
                currentWindow: Value(observedWindow),
                rowRevision: Value(row.rowRevision + 1),
              ),
            );
      }
      await (database.update(database.recoverbullState)
            ..where((t) => t.id.equals(1) & t.revision.equals(state.revision)))
          .write(
            RecoverbullStateCompanion(
              etag: conflicts > 0
                  ? const Value(null)
                  : snapshot.notModified
                  ? Value(state.etag)
                  : Value(snapshot.etag),
              collectionStartedAt: snapshot.notModified
                  ? Value(state.collectionStartedAt)
                  : Value(snapshot.collectionStartedAt),
              lastSuccessfulCheckAt: Value(DateTime.now().toUtc()),
              consecutiveFailures: const Value(0),
              attemptsUnsupportedUntil: const Value(null),
              revision: Value(state.revision + 1),
            ),
          );
      return RecoverBullAttemptMonitoringApplyResult(
        true,
        conflicts,
        eligibleDigests: eligibleDigests,
        alerts: alerts,
      );
    });
  }

  Future<RecoverBullAttemptMonitoringApplyResult> rebaseline(
    RecoverBullAttemptsSnapshot snapshot,
    RecoverBullAttemptMonitoringSnapshotToken token,
  ) async {
    if (_monitoringClosed) {
      return const RecoverBullAttemptMonitoringApplyResult(false, 0);
    }
    return database.transaction(() async {
      if (_monitoringClosed) {
        return const RecoverBullAttemptMonitoringApplyResult(false, 0);
      }
      final state = await database
          .select(database.recoverbullState)
          .getSingle();
      if (state.generation != token.generation ||
          state.revision != token.stateRevision) {
        return const RecoverBullAttemptMonitoringApplyResult(false, 0);
      }
      var conflicts = 0;
      final rows = await database
          .select(database.recoverbullMonitoredBackup)
          .get();
      for (final row in rows) {
        if (_ownActivityChanged(token, row.digest)) {
          conflicts++;
          continue;
        }
        final expectedRevision = token.rowRevisions.entries
            .where((entry) => _same(entry.key, row.digest))
            .map((entry) => entry.value)
            .firstOrNull;
        if (expectedRevision == null || expectedRevision != row.rowRevision) {
          conflicts++;
          continue;
        }
        final observed = _observed(snapshot, row.digest);
        final window = _window(
          snapshot.windowStartedAt.entries
                  .where((entry) => _same(entry.key, row.digest))
                  .map((entry) => entry.value)
                  .firstOrNull ??
              snapshot.collectionStartedAt,
        );
        await (database.update(database.recoverbullMonitoredBackup)..where(
              (t) =>
                  t.digest.equals(row.digest) &
                  t.rowRevision.equals(row.rowRevision),
            ))
            .write(
              RecoverbullMonitoredBackupCompanion(
                expectedServerDistinctCandidateTotal: Value(observed ?? 0),
                currentWindow: Value(window),
                lastWarningWindow: const Value(null),
                rowRevision: Value(row.rowRevision + 1),
              ),
            );
      }
      await (database.update(database.recoverbullState)
            ..where((t) => t.id.equals(1) & t.revision.equals(state.revision)))
          .write(
            RecoverbullStateCompanion(
              etag: conflicts > 0 ? const Value(null) : Value(snapshot.etag),
              collectionStartedAt: Value(snapshot.collectionStartedAt),
              lastSuccessfulCheckAt: Value(DateTime.now().toUtc()),
              consecutiveFailures: const Value(0),
              attemptsUnsupportedUntil: const Value(null),
              revision: Value(state.revision + 1),
            ),
          );
      return RecoverBullAttemptMonitoringApplyResult(true, conflicts);
    });
  }

  Future<RecoverBullPollFailureResult> recordPollFailure({
    required DateTime now,
    RecoverBullAttemptMonitoringSnapshotToken? token,
  }) async {
    if (_monitoringClosed) {
      return const RecoverBullPollFailureResult(false, false);
    }
    while (true) {
      if (_monitoringClosed) {
        return const RecoverBullPollFailureResult(false, false);
      }
      final state = await this.state();
      if (!state.attemptMonitoringEnabled ||
          (token != null &&
              (state.generation != token.generation ||
                  state.revision != token.stateRevision))) {
        return const RecoverBullPollFailureResult(false, false);
      }
      final failures = state.consecutiveFailures + 1;
      final stale = state.lastSuccessfulCheckAt == null
          ? failures >= 3
          : now.difference(state.lastSuccessfulCheckAt!) >=
                const Duration(days: 3);
      final canWarn =
          stale &&
          (state.lastUnavailabilityWarningAt == null ||
              now.difference(state.lastUnavailabilityWarningAt!) >=
                  const Duration(days: 1));
      final updated =
          await (database.update(database.recoverbullState)..where(
                (t) => t.id.equals(1) & t.revision.equals(state.revision),
              ))
              .write(
                RecoverbullStateCompanion(
                  consecutiveFailures: Value(failures),
                  lastUnavailabilityWarningAt: canWarn
                      ? Value(now)
                      : const Value.absent(),
                  revision: Value(state.revision + 1),
                ),
              );
      if (updated == 1) return RecoverBullPollFailureResult(true, canWarn);
    }
  }

  /// Remembers that the key server lacks `/attempts` until [until], so
  /// neither the launch check nor a key fetch probes it again before then.
  Future<void> recordAttemptsUnsupported({
    required DateTime until,
    RecoverBullAttemptMonitoringSnapshotToken? token,
  }) async {
    if (_monitoringClosed) return;
    await database.transaction(() async {
      if (_monitoringClosed) return;
      final current = await state();
      if (!current.attemptMonitoringEnabled) return;
      if (token != null &&
          (current.generation != token.generation ||
              current.revision != token.stateRevision)) {
        return;
      }
      await database
          .update(database.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              attemptsUnsupportedUntil: Value(until),
              revision: Value(current.revision + 1),
            ),
          );
    });
  }

  bool _rowTokenMatches(
    RecoverBullAttemptMonitoringSnapshotToken token,
    List<int> digest,
    int? revision,
  ) {
    final captured = token.rowRevisions.entries
        .where((entry) => _same(entry.key, digest))
        .map((entry) => entry.value)
        .firstOrNull;
    return captured == revision;
  }

  Future<bool> _isTokenCurrent(
    RecoverBullAttemptMonitoringSnapshotToken token,
  ) async {
    final current = await state();
    return current.generation == token.generation &&
        current.revision == token.stateRevision;
  }

  Future<Set<String>> acknowledgedAlertIdentities() async => {
    for (final row
        in await database.select(database.recoverbullAcknowledgedAlert).get())
      row.identity,
  };

  Future<void> acknowledgeAlert(String identity, {required DateTime at}) =>
      database
          .into(database.recoverbullAcknowledgedAlert)
          .insertOnConflictUpdate(
            RecoverbullAcknowledgedAlertCompanion.insert(
              identity: identity,
              acknowledgedAt: at,
            ),
          );

  Future<void> setEnabled(bool enabled) async {
    await database.transaction(() async {
      final state = await database
          .select(database.recoverbullState)
          .getSingle();
      await database
          .update(database.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              attemptMonitoringEnabled: Value(enabled),
              generation: Value(state.generation + 1),
              revision: Value(state.revision + 1),
              etag: const Value(null),
              collectionStartedAt: const Value(null),
              lastSuccessfulCheckAt: const Value(null),
              consecutiveFailures: const Value(0),
              lastUnavailabilityWarningAt: const Value(null),
              attemptsUnsupportedUntil: const Value(null),
            ),
          );
      _clearOwnOperations();
      _ownGeneration = state.generation + 1;
      if (!enabled) {
        await database.delete(database.recoverbullMonitoredBackup).go();
        await database.delete(database.recoverbullAcknowledgedAlert).go();
      }
    });
    if (!enabled) await _truncateWalBestEffort();
  }

  Future<void> reset() async {
    await database.transaction(() async {
      final state = await database
          .select(database.recoverbullState)
          .getSingle();
      _clearOwnOperations();
      _ownGeneration = state.generation + 1;
      await database.delete(database.recoverbullMonitoredBackup).go();
      await database.delete(database.recoverbullAcknowledgedAlert).go();
      await database
          .update(database.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              generation: Value(state.generation + 1),
              revision: Value(state.revision + 1),
              etag: const Value(null),
              collectionStartedAt: const Value(null),
              lastSuccessfulCheckAt: const Value(null),
              attemptsUnsupportedUntil: const Value(null),
              consecutiveFailures: const Value(0),
              lastUnavailabilityWarningAt: const Value(null),
            ),
          );
    });
    await _truncateWalBestEffort();
  }

  static SuspiciousActivityAlert _snapshotAlert(
    RecoverbullMonitoredBackupData row,
    int observed,
    int window,
  ) => SuspiciousActivityAlert(
    backupIdHash: _hex(row.digest),
    observedTotal: observed,
    expectedTotal: row.expectedServerDistinctCandidateTotal,
    windowStartedAt: DateTime.fromMillisecondsSinceEpoch(
      window * 1000,
      isUtc: true,
    ),
  );

  static MonitoredBackup _monitoredBackup(RecoverbullMonitoredBackupData row) =>
      MonitoredBackup(
        digest: row.digest,
        expectedServerDistinctCandidateTotal:
            row.expectedServerDistinctCandidateTotal,
        currentWindow: row.currentWindow,
        lastWarningWindow: row.lastWarningWindow,
        rowRevision: row.rowRevision,
        origin: _origin(row.origin),
        driveAccountHash: row.driveAccountHash,
        driveFileId: row.driveFileId,
        driveFileCreatedAt: row.driveFileCreatedAt,
        driveFileModifiedAt: row.driveFileModifiedAt,
      );

  static AttemptMonitoringState _state(RecoverbullStateData row) =>
      AttemptMonitoringState(
        attemptMonitoringEnabled: row.attemptMonitoringEnabled,
        etag: row.etag,
        lastSuccessfulCheckAt: row.lastSuccessfulCheckAt,
        collectionStartedAt: row.collectionStartedAt,
        consecutiveFailures: row.consecutiveFailures,
        lastUnavailabilityWarningAt: row.lastUnavailabilityWarningAt,
        attemptsUnsupportedUntil: row.attemptsUnsupportedUntil,
        generation: row.generation,
        revision: row.revision,
      );

  static DriveBackupCacheEntry _driveCacheEntry(
    RecoverbullDriveBackupCacheData row,
  ) => DriveBackupCacheEntry(
    accountHash: row.accountHash,
    driveFileId: row.driveFileId,
    backupDigest: row.backupDigest,
    driveFileCreatedAt: row.driveFileCreatedAt,
    driveFileModifiedAt: row.driveFileModifiedAt,
  );

  static MonitoredBackupOrigin _origin(String value) => switch (value) {
    'created' => MonitoredBackupOrigin.created,
    'adopted' => MonitoredBackupOrigin.adopted,
    'drive' => MonitoredBackupOrigin.drive,
    _ => throw const FormatException('Unknown monitored backup origin'),
  };

  static String _originColumn(MonitoredBackupOrigin value) => switch (value) {
    MonitoredBackupOrigin.created => 'created',
    MonitoredBackupOrigin.adopted => 'adopted',
    MonitoredBackupOrigin.drive => 'drive',
  };

  Future<RecoverbullMonitoredBackupData?> _row(Uint8List digest) async =>
      (database.select(
        database.recoverbullMonitoredBackup,
      )..where((t) => t.digest.equals(digest))).getSingleOrNull();

  Future<void> _truncateWalBestEffort() async {
    try {
      await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } on Exception catch (_) {}
  }

  static int? _observed(
    RecoverBullAttemptsSnapshot snapshot,
    List<int> digest,
  ) {
    for (final entry in snapshot.totalAttempts.entries) {
      if (_same(entry.key, digest)) return entry.value;
    }
    return null;
  }

  static Uint8List _digest(List<int> value) =>
      Uint8List.fromList(convert.hex.decode(attemptsIdHash(value)));
  static List<int> _decodeHash(String value) => Uint8List.fromList(
    List<int>.generate(
      value.length ~/ 2,
      (i) => int.parse(value.substring(i * 2, i * 2 + 2), radix: 16),
    ),
  );
  static int _window(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(
          utc.year,
          utc.month,
          utc.day,
          utc.hour,
        ).millisecondsSinceEpoch ~/
        1000;
  }

  /// Reconciliation only compares accounts for equality, so a digest of the
  /// normalized address serves it without keeping the address at rest.
  static String _accountHash(String account) =>
      sha256.convert(utf8.encode(account.trim().toLowerCase())).toString();

  static String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  static bool _same(List<int> a, List<int> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
}

final class _OwnOperation {
  final RecoverBullOwnAttemptOperation operation;
  final String candidate;
  final int window;
  const _OwnOperation(this.operation, this.candidate, this.window);
}
