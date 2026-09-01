import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../database/recoverbull_database.dart';
import '../domain/entities/key_server_attempts.dart';

/// Only this port is visible to the controller. The production adapter in the
/// data layer supplies the pinned recoverbull client's `/attempts` result.
abstract interface class RecoverBullAttemptMonitoringRemotePort {
  Future<RecoverBullAttemptsSnapshot?> poll({
    required String? etag,
    required List<String> backupDigests,
  });
}

final class RecoverBullAttemptsSnapshot {
  final String? etag;
  final DateTime collectionStartedAt;
  final Map<List<int>, int> totalAttempts;
  final Map<List<int>, DateTime> windowStartedAt;
  final bool serviceBusy;
  final bool notModified;
  final int? totalEntries;
  final int? maxAttemptIdentifiers;
  final List<List<int>> targetedLockouts;

  const RecoverBullAttemptsSnapshot({
    required this.collectionStartedAt,
    required this.totalAttempts,
    this.windowStartedAt = const {},
    this.etag,
    this.serviceBusy = false,
    this.notModified = false,
    this.totalEntries,
    this.maxAttemptIdentifiers,
    this.targetedLockouts = const [],
  });
}

final class RecoverBullAttemptMonitoringSnapshotToken {
  final int generation;
  final int stateRevision;
  final Map<Uint8List, int> rowRevisions;
  final String? etag;

  const RecoverBullAttemptMonitoringSnapshotToken({
    required this.generation,
    required this.stateRevision,
    required this.rowRevisions,
    required this.etag,
  });
}

enum MonitoredBackupOrigin { created, adopted }

final class RecoverBullAttemptMonitoringApplyResult {
  final bool accepted;
  final int conflicts;

  const RecoverBullAttemptMonitoringApplyResult(this.accepted, this.conflicts);
}

final class RecoverBullAttemptMonitoringStore {
  static Future<void> _writeTail = Future<void>.value();
  final RecoverBullDatabase database;

  RecoverBullAttemptMonitoringStore(this.database);

  Future<List<RecoverbullMonitoredBackupData>> monitoredBackups() =>
      database.select(database.recoverbullMonitoredBackup).get();

  Future<RecoverbullStateData> state() =>
      database.select(database.recoverbullState).getSingle();

  Future<void> replaceBackup(AttemptMonitoringBackupState value) async {
    final digest = Uint8List.fromList(_decodeHash(value.backupIdHash));
    await _serializeWrite(() async {
      for (var attempt = 0; attempt < 3; attempt++) {
        final changed = await database.transaction(() async {
          final row = await _row(digest);
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
      throw StateError(
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
  }) async {
    if (observedTotal < 0) throw ArgumentError.value(observedTotal);
    if (window < 0) throw ArgumentError.value(window);
    final digest = _digest(identifier);
    final adopted = origin == MonitoredBackupOrigin.adopted;
    await database.transaction(() async {
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
            ),
            mode: InsertMode.insertOrIgnore,
          );
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
      throw StateError(
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
        } catch (error) {
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
      final rows = await database
          .select(database.recoverbullMonitoredBackup)
          .get();
      return RecoverBullAttemptMonitoringSnapshotToken(
        generation: state.generation,
        stateRevision: state.revision,
        etag: state.etag,
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
    final resolvedToken = token ?? await captureToken();
    return database.transaction(() async {
      final state = await database
          .select(database.recoverbullState)
          .getSingle();
      if (state.generation != resolvedToken.generation ||
          state.revision != resolvedToken.stateRevision) {
        return const RecoverBullAttemptMonitoringApplyResult(false, 0);
      }
      var conflicts = 0;
      final rows = await database
          .select(database.recoverbullMonitoredBackup)
          .get();
      for (final row in rows) {
        final revision = resolvedToken.rowRevisions.entries
            .where((entry) => _same(entry.key, row.digest))
            .map((entry) => entry.value)
            .firstOrNull;
        if (revision == null || revision != row.rowRevision) {
          conflicts++;
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
                  expectedServerDistinctCandidateTotal: Value(observed),
                  currentWindow: Value(observedWindow),
                  rowRevision: Value(row.rowRevision + 1),
                ),
              );
          continue;
        }
        if (observed <= row.expectedServerDistinctCandidateTotal) continue;
        await (database.update(database.recoverbullMonitoredBackup)..where(
              (t) =>
                  t.digest.equals(row.digest) &
                  t.rowRevision.equals(row.rowRevision),
            ))
            .write(
              RecoverbullMonitoredBackupCompanion(
                lastWarningWindow: Value(observedWindow),
                rowRevision: Value(row.rowRevision + 1),
              ),
            );
      }
      await (database.update(database.recoverbullState)
            ..where((t) => t.id.equals(1) & t.revision.equals(state.revision)))
          .write(
            RecoverbullStateCompanion(
              etag: snapshot.notModified
                  ? Value(state.etag)
                  : Value(snapshot.etag),
              collectionStartedAt: snapshot.notModified
                  ? Value(state.collectionStartedAt)
                  : Value(snapshot.collectionStartedAt),
              lastSuccessfulCheckAt: Value(DateTime.now().toUtc()),
              consecutiveFailures: const Value(0),
              revision: Value(state.revision + 1),
            ),
          );
      return RecoverBullAttemptMonitoringApplyResult(true, conflicts);
    });
  }

  Future<RecoverBullAttemptMonitoringApplyResult> rebaseline(
    RecoverBullAttemptsSnapshot snapshot,
    RecoverBullAttemptMonitoringSnapshotToken token,
  ) async {
    return database.transaction(() async {
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
              etag: Value(snapshot.etag),
              collectionStartedAt: Value(snapshot.collectionStartedAt),
              lastSuccessfulCheckAt: Value(DateTime.now().toUtc()),
              consecutiveFailures: const Value(0),
              revision: Value(state.revision + 1),
            ),
          );
      return RecoverBullAttemptMonitoringApplyResult(true, conflicts);
    });
  }

  Future<bool> recordPollFailure({required DateTime now}) async {
    while (true) {
      final state = await this.state();
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
      if (updated == 1) return canWarn;
    }
  }

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
            ),
          );
      if (!enabled) {
        await database.delete(database.recoverbullMonitoredBackup).go();
      }
    });
    if (!enabled) await _truncateWalBestEffort();
  }

  Future<void> reset() async {
    await database.transaction(() async {
      final state = await database
          .select(database.recoverbullState)
          .getSingle();
      await database.delete(database.recoverbullMonitoredBackup).go();
      await database
          .update(database.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              generation: Value(state.generation + 1),
              revision: Value(state.revision + 1),
              etag: const Value(null),
              collectionStartedAt: const Value(null),
              lastSuccessfulCheckAt: const Value(null),
            ),
          );
    });
    await _truncateWalBestEffort();
  }

  Future<RecoverbullMonitoredBackupData?> _row(Uint8List digest) async =>
      (database.select(
        database.recoverbullMonitoredBackup,
      )..where((t) => t.digest.equals(digest))).getSingleOrNull();

  Future<void> _truncateWalBestEffort() async {
    try {
      await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
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
      Uint8List.fromList(sha256.convert(value).bytes);
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

  static int collectionSecond(DateTime value) =>
      value.toUtc().millisecondsSinceEpoch ~/ 1000;

  static bool _same(List<int> a, List<int> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
}
