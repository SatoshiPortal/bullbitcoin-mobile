import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_telemetry_alert.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_tor/tor.dart';

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
  final EnsureRecoverBullTorSessionUsecase ensureRecoverBullTorSessionUsecase;

  CheckBackupTelemetryUsecase({
    required this.recoverBullRepository,
    required this.ensureRecoverBullTorSessionUsecase,
  });

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
      final serverUrl = (await recoverBullRepository.fetchUrl()).toString();
      final backups = await recoverBullRepository.fetchTelemetryBackups(
        serverUrl,
      );
      if (backups.isEmpty) return const Ok([]);

      final now = DateTime.now();
      final serverState = await recoverBullRepository.fetchTelemetryServerState(
        serverUrl,
      );

      // Skip when the last successful check is fresh: the server rebuilds
      // the snapshot at most once per minute anyway.
      final lastSuccess = serverState?.lastSuccessfulCheckAt;
      if (lastSuccess != null &&
          now.difference(lastSuccess) < snapshotFreshness) {
        return const Ok([]);
      }

      // Only now is a route worth opening: there is something to monitor and
      // the last check is stale. The session is closed in the `finally`, so
      // the check never leaks an embedded-Tor session into the background.
      final session = await ensureRecoverBullTorSessionUsecase.execute();
      if (session case Err(:final failure)) return Err(failure);
      final route =
          (session as Ok<RecoverBullTorRoute, RecoverBullCoreFailure>).value;
      try {
        return await _check(
          serverUrl: serverUrl,
          backups: backups,
          serverState: serverState,
          endpoint: route.endpoint,
          now: now,
        );
      } finally {
        await route.close();
      }
    } catch (e) {
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  Future<Result<List<RecoverbullTelemetryAlert>, RecoverBullCoreFailure>>
  _check({
    required String serverUrl,
    required List<TelemetryBackupState> backups,
    required TelemetryServerState? serverState,
    required TorProxyEndpoint endpoint,
    required DateTime now,
  }) async {
    try {
      final alerts = <RecoverbullTelemetryAlert>[];

      // /info: wipe detection + map capacity (best effort — a failure here
      // must not block the snapshot check).
      DateTime? collectionStartedAt;
      int? maxAttemptIdentifiers;
      switch (await recoverBullRepository.fetchServerInfo(endpoint)) {
        case Ok(:final value):
          collectionStartedAt = value.collectionStartedAt;
          maxAttemptIdentifiers = value.maxAttemptIdentifiers;
        case Err():
          break;
      }

      // Wipe detection: a changed collection start means the server
      // restarted and wiped its in-memory counters.
      var currentEtag = serverState?.lastEtag;
      var persistedCollectionStartedAt = serverState?.collectionStartedAt;
      if (collectionStartedAt != null) {
        final persisted = serverState?.collectionStartedAt;
        if (persisted != null &&
            !persisted.isAtSameMomentAs(collectionStartedAt)) {
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
        persistedCollectionStartedAt = collectionStartedAt;
      }

      // Snapshot check.
      final hashes = backups.map((b) => b.backupIdHash).toList();
      var consecutiveFailures = serverState?.consecutiveFailures ?? 0;
      var unavailabilityWarnedAt = serverState?.unavailabilityWarnedAt;
      var checkSucceeded = false;

      switch (await recoverBullRepository.fetchTelemetrySnapshot(
        endpoint,
        etag: currentEtag,
        backupIdHashes: hashes,
      )) {
        case Err(:final failure):
          // Service pressure gets its own softer immediate notice, but only
          // when the server actually said so (503). A server we could not
          // reach must not be described as overloaded — it only counts toward
          // the prolonged-unavailability warning below.
          if (failure is KeyServerBusyFailure) {
            alerts.add(
              const ServicePressureAlert(ServicePressureKind.serviceBusy),
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
              : now.difference(lastSuccess);
          final warnedRecently =
              unavailabilityWarnedAt != null &&
              now.difference(unavailabilityWarnedAt) <
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
            unavailabilityWarnedAt = now;
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
        TelemetryServerState(
          serverUrl: serverUrl,
          lastEtag: currentEtag,
          lastSuccessfulCheckAt: checkSucceeded
              ? now
              : serverState?.lastSuccessfulCheckAt,
          collectionStartedAt: persistedCollectionStartedAt,
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
    required List<TelemetryBackupState> backups,
    required List<KeyServerAttemptEntry> matchingEntries,
    required List<RecoverbullTelemetryAlert> alerts,
  }) async {
    final byHash = {for (final e in matchingEntries) e.idHash: e};

    for (final backup in backups) {
      final entry = byHash[backup.backupIdHash];

      if (entry == null) {
        // Not in the snapshot: the window expired (cooldown elapsed) or the
        // server wiped. The local counter is stale — reset it silently.
        if (backup.expectedTotalAttempts != 0 || backup.currentWindow != null) {
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
      final expected = backup.currentWindow == entryWindow
          ? backup.expectedTotalAttempts
          : 0;

      if (entry.totalAttempts > expected &&
          backup.lastWarningWindow != entryWindow) {
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
          backup.currentWindow != entryWindow) {
        await recoverBullRepository.upsertTelemetryBackup(
          _rebuild(backup, expected: expected, window: entryWindow),
        );
      }
    }
  }

  static TelemetryBackupState _rebuild(
    TelemetryBackupState backup, {
    required int expected,
    required int? window,
    int? lastWarningWindow,
  }) {
    return TelemetryBackupState(
      serverUrl: backup.serverUrl,
      backupIdHash: backup.backupIdHash,
      expectedTotalAttempts: expected,
      currentWindow: window,
      lastWarningWindow: lastWarningWindow ?? backup.lastWarningWindow,
      acknowledgedAt: backup.acknowledgedAt,
    );
  }
}
