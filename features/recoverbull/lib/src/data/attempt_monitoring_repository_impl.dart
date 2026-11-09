import 'package:bull_logger/bull_logger.dart';
import 'package:convert/convert.dart' show hex;
import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/attempt_observation.dart';
import '../domain/entities/backup_monitoring.dart';
import '../domain/entities/backup_settings.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/repositories/attempt_monitoring_repository.dart';
import 'database/recoverbull_database.dart';
import 'recoverbull_storage_failure.dart';

/// Own credits are cumulative since the window anchor, never re-used by a poll.
/// Unresolved operations survive process death and deliberately reduce coverage.
final class AttemptMonitoringRepositoryImpl
    implements AttemptMonitoringRepository {
  final RecoverBullDatabase _database;
  final bool _durable;
  final RecoverBullFailure? _unavailableFailure;

  AttemptMonitoringRepositoryImpl(
    this._database, {
    required this._durable,
    this._unavailableFailure,
  });

  Uint8List _digest(EncryptedVault vault) =>
      Uint8List.fromList(sha256.convert(hex.decode(vault.id)).bytes);
  Future<RecoverbullStateData> _state() =>
      _database.select(_database.recoverbullState).getSingle();

  bool _current(RecoverbullStateData state, BackupSettings settings) =>
      state.server == settings.server.toString() &&
      state.generation == settings.generation &&
      state.permissionGranted;

  Future<void> _revision() => _database.customStatement(
    'UPDATE recoverbull_state SET monitoring_revision = monitoring_revision + 1',
  );

  Future<void> _enroll(String server, Uint8List digest) async {
    await _database
        .into(_database.recoverbullMonitoredVaults)
        .insert(
          RecoverbullMonitoredVaultsCompanion.insert(
            server: server,
            digest: digest,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<Result<void, RecoverBullFailure>> register(
    BackupSettings settings,
    EncryptedVault vault,
  ) => _guard(() async {
    if (!_durable) {
      return Err(_unavailableFailure ?? const RecoverBullJournalFailure());
    }
    if (!_current(await _state(), settings)) {
      return const Err(VaultContextChangedFailure());
    }
    await _enroll(settings.server.toString(), _digest(vault));
    await _revision();
    return const Ok(null);
  });

  @override
  Future<Result<OwnBackupOperation, RecoverBullFailure>> begin(
    BackupSettings settings,
    EncryptedVault vault,
  ) => _guard(() async {
    // This is mandatory even with monitoring opted out. A memory database
    // cannot durably establish that the following network request is ours.
    if (!_durable) {
      return Err(_unavailableFailure ?? const RecoverBullJournalFailure());
    }
    if (!_current(await _state(), settings)) {
      return const Err(VaultContextChangedFailure());
    }
    final server = settings.server.toString();
    final digest = _digest(vault);
    await _enroll(server, digest);
    final id = await _database
        .into(_database.recoverbullOwnOperations)
        .insert(
          RecoverbullOwnOperationsCompanion.insert(
            server: server,
            digest: digest,
          ),
        );
    await _database.customStatement(
      'UPDATE recoverbull_monitored_vaults SET own_requests = own_requests + 1, unknown = 1 WHERE server = ? AND digest = ?',
      [server, digest],
    );
    await _revision();
    return Ok(OwnBackupOperation(id, settings));
  });

  Future<int> _pending(String server, Uint8List digest) async =>
      (await _database
              .customSelect(
                'SELECT count(*) AS n FROM recoverbull_own_operations WHERE server = ? AND digest = ?',
                variables: [Variable(server), Variable(digest)],
              )
              .getSingle())
          .read<int>('n');

  @override
  Future<Result<void, RecoverBullFailure>> complete(
    OwnBackupOperation operation, {
    AttemptObservation? observation,
    bool lockout = false,
    bool trashed = false,
  }) => _guard(() async {
    final pending = await (_database.select(
      _database.recoverbullOwnOperations,
    )..where((row) => row.id.equals(operation.id))).getSingleOrNull();
    if (pending == null) return const Ok(null);
    final state = await _state();
    // Revocation invalidates completion but preserves the sent-operation marker.
    if (!_current(state, operation.settings)) return const Ok(null);
    final row =
        await (_database.select(_database.recoverbullMonitoredVaults)..where(
              (row) =>
                  row.server.equals(pending.server) &
                  row.digest.equals(pending.digest),
            ))
            .getSingle();
    if (trashed) {
      await (_database.delete(_database.recoverbullMonitoredVaults)..where(
            (row) =>
                row.server.equals(pending.server) &
                row.digest.equals(pending.digest),
          ))
          .go();
      await (_database.delete(_database.recoverbullAlerts)..where(
            (row) =>
                row.server.equals(pending.server) &
                row.digest.equals(pending.digest),
          ))
          .go();
      await (_database.delete(_database.recoverbullOwnOperations)..where(
            (row) =>
                row.server.equals(pending.server) &
                row.digest.equals(pending.digest),
          ))
          .go();
    } else {
      if (lockout && state.monitoringEnabled) {
        await _alert(row, row.window ?? 0, BackupAlertKind.lockout);
      }
      if (observation != null) {
        await _apply(
          row,
          observation,
          null,
          enabled: state.monitoringEnabled,
          completing: true,
        );
        await (_database.delete(
          _database.recoverbullOwnOperations,
        )..where((row) => row.id.equals(operation.id))).go();
      }
      // A missing response/status, including a timeout, does not prove that the
      // server will not count this request later. Its credit never expires.
    }
    await _revision();
    return const Ok(null);
  });

  @override
  Future<Result<MonitoringCheck?, RecoverBullFailure>> prepare() =>
      _guard(() async {
        final state = await _state();
        if (!_durable || !state.permissionGranted || !state.monitoringEnabled) {
          return const Ok(null);
        }
        final rows = await (_database.select(
          _database.recoverbullMonitoredVaults,
        )..where((row) => row.server.equals(state.server))).get();
        if (rows.isEmpty) return const Ok(null);
        return Ok(
          MonitoringCheck(
            BackupSettings(
              server: Uri.parse(state.server),
              permissionGranted: true,
              monitoringEnabled: true,
              generation: state.generation,
            ),
            state.monitoringRevision,
            rows.map((row) => hex.encode(row.digest)).toSet(),
          ),
        );
      });

  @override
  Future<Result<void, RecoverBullFailure>> observe(
    MonitoringCheck check,
    AttemptSnapshot? snapshot,
  ) => _guard(() async {
    final state = await _state();
    if (!_current(state, check.settings) ||
        !state.monitoringEnabled ||
        state.monitoringRevision != check.revision) {
      return const Ok(null);
    }
    final rows = await (_database.select(
      _database.recoverbullMonitoredVaults,
    )..where((row) => row.server.equals(state.server))).get();
    for (final row in rows) {
      final sample = snapshot?.entries[hex.encode(row.digest)];
      if (sample == null) {
        await _write(
          row,
          const RecoverbullMonitoredVaultsCompanion(unknown: Value(true)),
        );
      } else {
        await _apply(
          row,
          sample,
          snapshot?.collectionStartedAt.millisecondsSinceEpoch,
          enabled: true,
        );
      }
    }
    await _revision();
    return const Ok(null);
  });

  Future<void> _apply(
    RecoverbullMonitoredVault row,
    AttemptObservation sample,
    int? collection, {
    required bool enabled,
    bool completing = false,
  }) async {
    final window = sample.windowStartedAt.millisecondsSinceEpoch;
    final anchor = row.anchorRequests;
    final previousWindow = row.window;
    final previousCollection = row.collection;
    final pending = await _pending(row.server, row.digest);
    // Cached snapshots may precede an inline status; never move backwards.
    if ((previousWindow != null && window < previousWindow) ||
        (collection != null &&
            previousCollection != null &&
            collection < previousCollection)) {
      return;
    }
    final discontinuity =
        anchor == null ||
        window != previousWindow ||
        (collection != null &&
            previousCollection != null &&
            collection != previousCollection);
    if (discontinuity) {
      await _write(
        row,
        RecoverbullMonitoredVaultsCompanion(
          anchorRequests: Value(sample.requests),
          observedRequests: Value(sample.requests),
          window: Value(window),
          collection: collection == null
              ? const Value.absent()
              : Value(collection),
          ownRequests: Value(pending),
          unknown: const Value(true),
        ),
      );
      return;
    }
    final highest = row.observedRequests;
    if (highest != null && sample.requests < highest) {
      await _write(
        row,
        const RecoverbullMonitoredVaultsCompanion(unknown: Value(true)),
      );
      return;
    }
    if (enabled && sample.requests - anchor > row.ownRequests) {
      await _alert(row, window, BackupAlertKind.unexplainedActivity);
    }
    await _write(
      row,
      RecoverbullMonitoredVaultsCompanion(
        observedRequests: Value(sample.requests),
        collection: collection == null
            ? const Value.absent()
            : Value(collection),
        unknown: Value(pending > (completing ? 1 : 0)),
      ),
    );
  }

  Future<void> _write(
    RecoverbullMonitoredVault row,
    RecoverbullMonitoredVaultsCompanion values,
  ) async {
    await (_database.update(_database.recoverbullMonitoredVaults)..where(
          (entry) =>
              entry.server.equals(row.server) & entry.digest.equals(row.digest),
        ))
        .write(values);
  }

  Future<void> _alert(
    RecoverbullMonitoredVault row,
    int window,
    BackupAlertKind kind,
  ) async {
    await _database
        .into(_database.recoverbullAlerts)
        .insert(
          RecoverbullAlertsCompanion.insert(
            server: row.server,
            digest: row.digest,
            window: window,
            kind: kind.name,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<Result<BackupMonitoring, RecoverBullFailure>> status() => _guard(
    () async {
      final state = await _state();
      final rows = await (_database.select(
        _database.recoverbullMonitoredVaults,
      )..where((row) => row.server.equals(state.server))).get();
      final alerts =
          await (_database.select(_database.recoverbullAlerts)..where(
                (row) =>
                    row.server.equals(state.server) &
                    row.acknowledged.equals(false),
              ))
              .get();
      return Ok(
        BackupMonitoring(
          unknown:
              !_durable ||
              !state.permissionGranted ||
              !state.monitoringEnabled ||
              rows.isEmpty ||
              rows.any((row) => row.unknown),
          alerts: [
            for (final alert in alerts)
              BackupAlert(alert.id, BackupAlertKind.values.byName(alert.kind)),
          ],
        ),
      );
    },
  );

  @override
  Future<Result<void, RecoverBullFailure>> acknowledge(int acknowledgement) =>
      _guard(() async {
        final state = await _state();
        await (_database.update(_database.recoverbullAlerts)..where(
              (row) =>
                  row.server.equals(state.server) &
                  row.id.equals(acknowledgement),
            ))
            .write(const RecoverbullAlertsCompanion(acknowledged: Value(true)));
        return const Ok(null);
      });

  Future<Result<T, RecoverBullFailure>> _guard<T>(
    Future<Result<T, RecoverBullFailure>> Function() action,
  ) async {
    try {
      return await _database.transaction(action);
    } on Exception catch (error) {
      final failure = recoverBullStorageFailure(error);
      log.warning(switch (failure) {
        RecoverBullStorageFullFailure() => 'recoverbull.storage.full',
        RecoverBullStorageDamagedFailure() => 'recoverbull.storage.damaged',
        _ => 'recoverbull.storage.write.failed',
      });
      return Err(failure);
    }
  }
}
