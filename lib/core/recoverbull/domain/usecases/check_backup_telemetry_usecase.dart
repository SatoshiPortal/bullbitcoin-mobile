import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_telemetry_alert.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// The cold-launch telemetry check: polls `/attempts` conditionally and
/// derives advisory alerts from the server's public attempt counters.
///
/// Runs at most once per [snapshotFreshness] (the server rebuilds the
/// snapshot at most once per minute anyway), never in the background, and
/// never blocks startup or recovery: every failure degrades to silence
/// except the prolonged-unavailability soft warning.
///
/// Trust model: telemetry is advisory. The server cannot distinguish an
/// attacker from the user or another of the user's devices, and a
/// compromised server can fabricate or suppress counters.
class CheckBackupTelemetryUsecase {
  final RecoverBullRepository recoverBullRepository;

  CheckBackupTelemetryUsecase({required this.recoverBullRepository});

  /// Skip the check when the last successful one is younger than this
  /// (the server rebuilds the snapshot at most once per minute anyway).
  static const snapshotFreshness = Duration(seconds: 60);

  /// `/attempts` unreachable for longer than this surfaces the soft
  /// unavailability warning (flooding the route is the realistic way to
  /// suppress telemetry during an attack).
  static const unavailabilityThreshold = Duration(days: 3);

  /// Minimum delay between two unavailability warnings.
  static const unavailabilityWarnCooldown = Duration(days: 1);

  /// When monitoring never succeeded yet, this many consecutive failures are
  /// required before warning: a single transient failure on first launch
  /// (Tor still settling) must not alarm.
  static const minFailuresWithoutSuccess = 3;

  /// Snapshot fullness ratio (`totalEntries / maxAttemptIdentifiers`)
  /// triggering a service-pressure notice.
  static const mapFullnessThreshold = 0.85;

  Future<Result<List<RecoverbullTelemetryAlert>, RecoverBullCoreFailure>>
  execute() async {
    try {
      final alerts = <RecoverbullTelemetryAlert>[];
      final serverUrl = (await recoverBullRepository.fetchUrl()).toString();
      final backups = await recoverBullRepository.fetchTelemetryBackups(
        serverUrl,
      );
      if (backups.isEmpty) return const Ok([]);

      final now = DateTime.now();
      var serverState = await recoverBullRepository.fetchTelemetryServerState(
        serverUrl,
      );

      // Skip when the last successful check is fresh: the server rebuilds
      // the snapshot at most once per minute anyway.
      final lastSuccess = serverState?.lastSuccessfulCheckAt;
      if (lastSuccess != null &&
          now.difference(_fromEpoch(lastSuccess)) < snapshotFreshness) {
        return const Ok([]);
      }

      // /info: wipe detection + map capacity (best effort — a failure here
      // must not block the snapshot check).
      DateTime? collectionStartedAt;
      int? maxAttemptIdentifiers;
      switch (await recoverBullRepository.fetchServerInfo()) {
        case Ok(:final value):
          collectionStartedAt = value.collectionStartedAt;
          maxAttemptIdentifiers = value.maxAttemptIdentifiers;
        case Err():
          break;
      }

      // Wipe detection: a changed collection start means the server
      // restarted and wiped its in-memory counters.
      var currentEtag = serverState?.lastEtag;
      var collectionStartedAtEpoch = serverState?.collectionStartedAt;
      if (collectionStartedAt != null) {
        final collectionEpoch = _toEpoch(collectionStartedAt);
        final persisted = serverState?.collectionStartedAt;
        if (persisted != null && persisted != collectionEpoch) {
          // The server restarted and wiped its counters: reset every
          // baseline, drop the stale ETag, and surface a neutral notice —
          // never an attack alarm.
          for (final backup in backups) {
            await recoverBullRepository.upsertTelemetryBackup(
              _rebuild(backup, expected: 0, window: null),
            );
          }
          alerts.add(CountersWipedAlert(wipedAt: collectionStartedAt));
          currentEtag = null;
        }
        collectionStartedAtEpoch = collectionEpoch;
      }

      // Snapshot check.
      final hashes = backups.map((b) => b.backupIdHash).toList();
      var consecutiveFailures = serverState?.consecutiveFailures ?? 0;
      var unavailabilityWarnedAt = serverState?.unavailabilityWarnedAt;
      var checkSucceeded = false;

      switch (await recoverBullRepository.fetchTelemetrySnapshot(
        etag: currentEtag,
        backupIdHashes: hashes,
      )) {
        case Err(:final failure):
          // Service pressure gets its own softer immediate notice...
          if (failure is KeyServerOverloadedFailure) {
            alerts.add(
              const ServicePressureAlert(ServicePressureKind.global429),
            );
          } else if (failure is KeyServerCapacityFailure) {
            alerts.add(
              const ServicePressureAlert(ServicePressureKind.capacity503),
            );
          }
          // ...but EVERY failure counts toward prolonged unavailability.
          // Flooding /attempts is the realistic way to suppress telemetry
          // during an attack, so a sustained flood must eventually escalate
          // to the "you are not being warned" alert instead of staying a
          // mild "service issue" notice forever.
          consecutiveFailures++;
          final lastSuccess = serverState?.lastSuccessfulCheckAt;
          final silentFor = lastSuccess == null
              ? null
              : now.difference(_fromEpoch(lastSuccess));
          final warnedRecently =
              unavailabilityWarnedAt != null &&
              now.difference(_fromEpoch(unavailabilityWarnedAt)) <
                  unavailabilityWarnCooldown;
          final shouldWarn =
              !warnedRecently &&
              (silentFor != null
                  ? silentFor >= unavailabilityThreshold
                  // never succeeded: no duration to report, and a single
                  // transient failure (Tor still settling on first launch)
                  // must not alarm — require repeated failures instead
                  : consecutiveFailures >= minFailuresWithoutSuccess);
          if (shouldWarn) {
            alerts.add(TelemetryUnavailableAlert(since: silentFor));
            unavailabilityWarnedAt = _toEpoch(now);
          }
        case Ok(:final value):
          checkSucceeded = true;
          consecutiveFailures = 0;
          switch (value) {
            case TelemetrySnapshotNotModified():
              break;
            case TelemetrySnapshotModified(
              :final etag,
              :final totalEntries,
              :final matchingEntries,
            ):
              currentEtag = etag;
              if (maxAttemptIdentifiers != null &&
                  maxAttemptIdentifiers > 0 &&
                  totalEntries >=
                      maxAttemptIdentifiers * mapFullnessThreshold) {
                alerts.add(
                  const ServicePressureAlert(ServicePressureKind.mapNearlyFull),
                );
              }
              await _reconcileBackups(
                backups: backups,
                matchingEntries: matchingEntries,
                alerts: alerts,
              );
          }
      }

      // Persist the polling state.
      await recoverBullRepository.upsertTelemetryServerState(
        RecoverbullTelemetryServerRow(
          serverUrl: serverUrl,
          lastEtag: currentEtag,
          lastSuccessfulCheckAt: checkSucceeded
              ? _toEpoch(now)
              : serverState?.lastSuccessfulCheckAt,
          collectionStartedAt: collectionStartedAtEpoch,
          consecutiveFailures: consecutiveFailures,
          unavailabilityWarnedAt: unavailabilityWarnedAt,
        ),
      );

      return Ok(alerts);
    } catch (e) {
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  /// Compares the snapshot entries against the per-backup baselines and
  /// raises [SuspiciousActivityAlert] where the server's counters exceed
  /// this device's own operations.
  Future<void> _reconcileBackups({
    required List<RecoverbullTelemetryBackupRow> backups,
    required List<KeyServerAttemptEntry> matchingEntries,
    required List<RecoverbullTelemetryAlert> alerts,
  }) async {
    final byHash = {for (final e in matchingEntries) e.idHash: e};

    for (final backup in backups) {
      final entry = byHash[backup.backupIdHash];

      if (entry == null) {
        // Not in the snapshot: the window expired (cooldown elapsed) or the
        // server wiped. The local counter is stale — reset it silently.
        if (backup.expectedTotalAttempts != 0 ||
            backup.currentWindowStartedAt != null) {
          await recoverBullRepository.upsertTelemetryBackup(
            _rebuild(backup, expected: 0, window: null),
          );
        }
        continue;
      }

      // same hour granularity as the record path: the snapshot is already
      // hour-truncated, applying the identity keeps both sides symmetric
      final entryWindow = telemetryWindowIdentity(entry.windowStartedAt);
      // A window mismatch means the local counter belongs to an expired
      // window: reset it before comparing.
      final expected = backup.currentWindowStartedAt == entryWindow
          ? backup.expectedTotalAttempts
          : 0;

      if (entry.totalAttempts > expected &&
          backup.lastWarningWindowStartedAt != entryWindow) {
        alerts.add(
          SuspiciousActivityAlert(
            backupIdHash: backup.backupIdHash,
            observedTotal: entry.totalAttempts,
            expectedTotal: expected,
            windowStartedAt: entry.windowStartedAt,
          ),
        );
        await recoverBullRepository.upsertTelemetryBackup(
          _rebuild(
            backup,
            expected: expected,
            window: entryWindow,
            lastWarningWindow: entryWindow,
          ),
        );
      } else if (expected != backup.expectedTotalAttempts ||
          backup.currentWindowStartedAt != entryWindow) {
        await recoverBullRepository.upsertTelemetryBackup(
          _rebuild(backup, expected: expected, window: entryWindow),
        );
      }
    }
  }

  static RecoverbullTelemetryBackupRow _rebuild(
    RecoverbullTelemetryBackupRow backup, {
    required int expected,
    required int? window,
    int? lastWarningWindow,
  }) {
    return RecoverbullTelemetryBackupRow(
      serverUrl: backup.serverUrl,
      backupIdHash: backup.backupIdHash,
      expectedTotalAttempts: expected,
      currentWindowStartedAt: window,
      lastWarningWindowStartedAt:
          lastWarningWindow ?? backup.lastWarningWindowStartedAt,
      acknowledgedAt: backup.acknowledgedAt,
    );
  }

  static int _toEpoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
  static DateTime _fromEpoch(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}
