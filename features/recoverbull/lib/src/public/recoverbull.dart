import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../database/recoverbull_database.dart';
import '../attempt_monitoring/recoverbull_attempt_monitoring.dart';
import '../domain/usecases/check_backup_attempt_monitoring_usecase.dart';
import '../domain/entities/attempt_alert.dart' as domain_alert;
import '../domain/recoverbull_attempt_alert_port.dart';
import '../domain/recoverbull_lifecycle_port.dart';
import '../domain/recoverbull_server_url.dart';

/// The production key server. Kept in the package so shell configuration is
/// not able to accidentally drift from the protocol default.
const recoverBullDefaultServerUrl =
    'http://5m7enm5y77tdgmaf3d5xuwa5c7fjma7v5ljtwxu4q5jtq6b5utspmpyd.onion';

typedef RecoverBullTiming =
    void Function(String phase, int durationMilliseconds, String outcome);

@immutable
final class RecoverBullConfig {
  final String databasePath;
  final Uri? defaultServer;
  final bool initialPermissionGranted;

  const RecoverBullConfig({
    required this.databasePath,
    this.defaultServer,
    this.initialPermissionGranted = false,
  });

  Uri get effectiveDefaultServer =>
      defaultServer ?? Uri.parse(recoverBullDefaultServerUrl);
}

@immutable
final class RecoverBullDependencies {
  final RecoverBullTiming? timing;

  const RecoverBullDependencies({this.timing});
}

@immutable
final class RecoverBullStatus {
  final DateTime? lastEncryptedBackupAt;
  final DateTime? lastVerifiedEncryptedBackupAt;
  final bool isKnown;

  const RecoverBullStatus({
    this.lastEncryptedBackupAt,
    this.lastVerifiedEncryptedBackupAt,
    this.isKnown = true,
  });

  bool get hasEncryptedBackup =>
      lastEncryptedBackupAt != null || lastVerifiedEncryptedBackupAt != null;

  bool get hasVerifiedEncryptedBackup => lastVerifiedEncryptedBackupAt != null;

  const RecoverBullStatus.initial()
    : lastEncryptedBackupAt = null,
      lastVerifiedEncryptedBackupAt = null,
      isKnown = true;

  const RecoverBullStatus.unavailable()
    : lastEncryptedBackupAt = null,
      lastVerifiedEncryptedBackupAt = null,
      isKnown = false;
}

enum RecoverBullHealth { online, offline, timeout }

@immutable
final class RecoverBullServerSettings {
  final Uri server;
  final bool permissionGranted;

  const RecoverBullServerSettings({
    required this.server,
    required this.permissionGranted,
  });
}

@immutable
final class RecoverBullMonitoringStatus {
  final bool enabled;
  final int monitoredCount;
  final DateTime? lastSuccessfulCheck;

  const RecoverBullMonitoringStatus({
    required this.enabled,
    required this.monitoredCount,
    required this.lastSuccessfulCheck,
  });

  bool get isUncovered => monitoredCount == 0;
}

enum RecoverBullAttemptAlertKind {
  suspiciousActivity,
  targetedLockout,
  servicePressure,
  unavailable,
  countersWiped,
}

final class RecoverBullAttemptAlert {
  final RecoverBullAttemptAlertKind kind;
  final String? backupReference;
  final int? observedTotal;
  final int? expectedTotal;
  final DateTime? windowStartedAt;
  final String _identity;

  RecoverBullAttemptAlert(this.kind)
    : backupReference = null,
      observedTotal = null,
      expectedTotal = null,
      windowStartedAt = null,
      _identity = kind.name;

  const RecoverBullAttemptAlert._(
    this.kind,
    this._identity, {
    this.backupReference,
    this.observedTotal,
    this.expectedTotal,
    this.windowStartedAt,
  });
}

abstract interface class RecoverBullAttemptMonitoringController {
  Future<List<RecoverBullAttemptAlert>> check();
  Future<List<RecoverBullAttemptAlert>> checkOnColdLaunch();
  Future<void> setEnabled(bool enabled);
  Future<void> acknowledge(RecoverBullAttemptAlert alert);
  bool get enabled;
  Stream<List<RecoverBullAttemptAlert>> get alerts;
  Future<RecoverBullMonitoringStatus> status();
}

final class RecoverBullAttemptMonitoring
    implements
        RecoverBullAttemptMonitoringController,
        RecoverBullAttemptAlertPort {
  final RecoverBullAttemptMonitoringStore _store;
  final Future<RecoverBullAttemptsSnapshot?> Function({
    required String? etag,
    required List<String> backupDigests,
  })?
  _poll;
  bool _enabled;
  final StreamController<List<RecoverBullAttemptAlert>> _alertUpdates =
      StreamController.broadcast();
  final List<RecoverBullAttemptAlert> _visibleAlerts = [];

  RecoverBullAttemptMonitoring(
    this._store, {
    this._enabled = false,
    this._poll,
  });

  @override
  bool get enabled => _enabled;

  @override
  Future<RecoverBullMonitoringStatus> status() async {
    final state = await _store.state();
    return RecoverBullMonitoringStatus(
      enabled: state.attemptMonitoringEnabled,
      monitoredCount: (await _store.monitoredBackups()).length,
      lastSuccessfulCheck: state.lastSuccessfulCheckAt,
    );
  }

  @override
  Stream<List<RecoverBullAttemptAlert>> get alerts async* {
    yield List.unmodifiable(_visibleAlerts);
    yield* _alertUpdates.stream;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await _store.setEnabled(enabled);
    _enabled = enabled;
  }

  @override
  Future<List<RecoverBullAttemptAlert>> check() async {
    if (!_enabled || _poll == null) return const [];
    try {
      final alerts = (await CheckBackupAttemptMonitoringUsecase(
        store: _store,
        remote: _CallbackAttemptMonitoringRemote(_poll),
      ).execute()).map(_publicAlert).toList(growable: false);
      for (final alert in alerts) {
        final alreadyVisible = _visibleAlerts.any(
          (visible) =>
              visible.kind == alert.kind &&
              visible._identity == alert._identity,
        );
        if (!alreadyVisible) _visibleAlerts.add(alert);
      }
      if (!_alertUpdates.isClosed) {
        _alertUpdates.add(List.unmodifiable(_visibleAlerts));
      }
      return alerts;
    } catch (_) {
      return const [];
    }
  }

  @override
  void publish(domain_alert.AttemptAlert alert) {
    final publicAlert = _publicAlert(alert);
    final alreadyVisible = _visibleAlerts.any(
      (visible) =>
          visible.kind == publicAlert.kind &&
          visible._identity == publicAlert._identity,
    );
    if (alreadyVisible) return;
    _visibleAlerts.add(publicAlert);
    if (!_alertUpdates.isClosed) {
      _alertUpdates.add(List.unmodifiable(_visibleAlerts));
    }
  }

  RecoverBullAttemptAlert _publicAlert(domain_alert.AttemptAlert alert) {
    return switch (alert) {
      domain_alert.SuspiciousActivityAlert(
        :final backupIdHash,
        :final observedTotal,
        :final expectedTotal,
        :final windowStartedAt,
      ) =>
        RecoverBullAttemptAlert._(
          RecoverBullAttemptAlertKind.suspiciousActivity,
          's:$backupIdHash:${windowStartedAt.toUtc().microsecondsSinceEpoch}',
          backupReference: _safeReference(backupIdHash),
          observedTotal: observedTotal,
          expectedTotal: expectedTotal,
          windowStartedAt: windowStartedAt,
        ),
      domain_alert.TargetedLockoutAlert(:final backupIdHash) =>
        RecoverBullAttemptAlert._(
          RecoverBullAttemptAlertKind.targetedLockout,
          'l:$backupIdHash',
          backupReference: _safeReference(backupIdHash),
        ),
      domain_alert.ServicePressureAlert(:final kind) =>
        RecoverBullAttemptAlert._(
          RecoverBullAttemptAlertKind.servicePressure,
          'p:$kind',
        ),
      domain_alert.AttemptMonitoringUnavailableAlert() =>
        RecoverBullAttemptAlert._(RecoverBullAttemptAlertKind.unavailable, 'u'),
      domain_alert.CountersWipedAlert(:final wipedAt) =>
        RecoverBullAttemptAlert._(
          RecoverBullAttemptAlertKind.countersWiped,
          'c:${wipedAt.toUtc().microsecondsSinceEpoch}',
        ),
    };
  }

  @override
  Future<List<RecoverBullAttemptAlert>> checkOnColdLaunch() => check();

  @override
  Future<void> acknowledge(RecoverBullAttemptAlert alert) async {
    _visibleAlerts.removeWhere(
      (candidate) => candidate._identity == alert._identity,
    );
    if (!_alertUpdates.isClosed) {
      _alertUpdates.add(List.unmodifiable(_visibleAlerts));
    }
  }

  static String _safeReference(String value) =>
      value.length <= 8 ? value : value.substring(0, 8);
}

final class _CallbackAttemptMonitoringRemote
    implements RecoverBullAttemptMonitoringRemotePort {
  final Future<RecoverBullAttemptsSnapshot?> Function({
    required String? etag,
    required List<String> backupDigests,
  })
  callback;
  const _CallbackAttemptMonitoringRemote(this.callback);

  @override
  Future<RecoverBullAttemptsSnapshot?> poll({
    required String? etag,
    required List<String> backupDigests,
  }) => callback(etag: etag, backupDigests: backupDigests);
}

final class RecoverBullLifecycle implements RecoverBullLifecyclePort {
  RecoverBullDatabase? _database;
  String? _path;
  bool _disposed = false;

  Future<void> open(
    String path, {
    bool initialPermissionGranted = false,
  }) async {
    await _openDatabase(
      path,
      initialPermissionGranted: initialPermissionGranted,
    );
  }

  Future<RecoverBullDatabase> openDatabase(
    String path, {
    bool initialPermissionGranted = false,
  }) => _openDatabase(path, initialPermissionGranted: initialPermissionGranted);

  Future<RecoverBullDatabase> _openDatabase(
    String path, {
    bool initialPermissionGranted = false,
  }) async {
    if (_disposed) throw StateError('RecoverBull lifecycle is disposed');
    if (_database != null && _path == path) return _database!;
    if (_database != null) {
      await _database!.close();
      _database = null;
      _path = null;
    }
    try {
      final database = RecoverBullDatabase.open(
        path,
        initialPermissionGranted: initialPermissionGranted,
      );
      await database.forceOpen();
      _database = database;
      _path = path;
      return database;
    } catch (error) {
      if (!_isCorruption(error)) rethrow;
      await _database?.close();
      _database = null;
      await _deleteFiles(path);
      final database = RecoverBullDatabase.open(
        path,
        initialPermissionGranted: initialPermissionGranted,
      );
      await database.forceOpen();
      _database = database;
      _path = path;
      return database;
    }
  }

  static bool _isCorruption(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('not a database') ||
        message.contains('malformed') ||
        message.contains('integrity check failed') ||
        message.contains('database disk image is malformed');
  }

  Future<void> dispose() async {
    final database = _database;
    _database = null;
    _path = null;
    if (database != null) await database.close();
    _disposed = true;
  }

  Future<void> reset(String path) async {
    await dispose();
    await _deleteFiles(path);
    _disposed = false;
  }

  Future<void> resetConfigured() async {
    final path = _path;
    if (path != null) await reset(path);
  }

  @override
  Future<void> markStored() async =>
      (await _openDatabase(_requirePath())).markEncryptedBackupStored();

  @override
  Future<void> markVerified() async =>
      (await _openDatabase(_requirePath())).markEncryptedBackupVerified();

  String _requirePath() {
    final path = _path;
    if (_disposed || path == null) {
      throw StateError('RecoverBull lifecycle is disposed or unopened');
    }
    return path;
  }

  static Future<void> _deleteFiles(String path) async {
    for (final suffix in ['', '-wal', '-shm', '-journal', '.sqlite-journal']) {
      final file = File('$path$suffix');
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}

final class RecoverBullCore {
  final RecoverBullConfig config;
  final RecoverBullDependencies dependencies;
  final RecoverBullLifecycle lifecycle;

  RecoverBullCore({
    required this.config,
    required this.dependencies,
    RecoverBullLifecycle? lifecycle,
  }) : lifecycle = lifecycle ?? RecoverBullLifecycle();

  Future<RecoverBullStatus> status() async {
    try {
      final db = await lifecycle._openDatabase(
        config.databasePath,
        initialPermissionGranted: config.initialPermissionGranted,
      );
      final row = await db.select(db.recoverbullState).getSingle();
      return RecoverBullStatus(
        lastEncryptedBackupAt: row.lastEncryptedBackupAt,
        lastVerifiedEncryptedBackupAt: row.lastVerifiedEncryptedBackupAt,
      );
    } catch (_) {
      return const RecoverBullStatus.unavailable();
    }
  }

  Future<RecoverBullServerSettings> serverSettings() async {
    final db = await lifecycle._openDatabase(
      config.databasePath,
      initialPermissionGranted: config.initialPermissionGranted,
    );
    final row = await db.select(db.recoverbullState).getSingle();
    return RecoverBullServerSettings(
      server: Uri.parse(
        row.serverUrlOverride ?? config.effectiveDefaultServer.toString(),
      ),
      permissionGranted: row.permissionGranted,
    );
  }

  Future<void> setServer(Uri server) async {
    validateRecoverBullServerUrl(server);
    final db = await lifecycle._openDatabase(
      config.databasePath,
      initialPermissionGranted: config.initialPermissionGranted,
    );
    await db.transaction(() async {
      final state = await db.select(db.recoverbullState).getSingle();
      final oldEffective = Uri.parse(
        state.serverUrlOverride ?? config.effectiveDefaultServer.toString(),
      );
      if (oldEffective == server) return;
      final monitoredBackups = await db
          .select(db.recoverbullMonitoredBackup)
          .get();
      for (final backup in monitoredBackups) {
        await (db.update(db.recoverbullMonitoredBackup)..where(
              (row) =>
                  row.digest.equals(backup.digest) &
                  row.rowRevision.equals(backup.rowRevision),
            ))
            .write(
              RecoverbullMonitoredBackupCompanion(
                expectedServerDistinctCandidateTotal: const Value(0),
                currentWindow: const Value(0),
                lastWarningWindow: const Value(null),
                rowRevision: Value(backup.rowRevision + 1),
              ),
            );
      }
      await db
          .update(db.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              serverUrlOverride: Value(
                server == config.effectiveDefaultServer
                    ? null
                    : server.toString(),
              ),
              permissionGranted: const Value(false),
              etag: const Value(null),
              collectionStartedAt: const Value(null),
              lastSuccessfulCheckAt: const Value(null),
              consecutiveFailures: const Value(0),
              lastUnavailabilityWarningAt: const Value(null),
              generation: Value(state.generation + 1),
              revision: Value(state.revision + 1),
            ),
          );
    });
  }

  Future<void> setPermission(bool granted) async {
    final db = await lifecycle._openDatabase(
      config.databasePath,
      initialPermissionGranted: config.initialPermissionGranted,
    );
    await db.transaction(() async {
      await db
          .update(db.recoverbullState)
          .write(RecoverbullStateCompanion(permissionGranted: Value(granted)));
    });
  }

  Future<void> markBackupStored() async {
    final db = await lifecycle._openDatabase(
      config.databasePath,
      initialPermissionGranted: config.initialPermissionGranted,
    );
    await db.markEncryptedBackupStored();
  }

  Future<void> markBackupVerified() async {
    final db = await lifecycle._openDatabase(
      config.databasePath,
      initialPermissionGranted: config.initialPermissionGranted,
    );
    await db.markEncryptedBackupVerified();
  }

  Future<RecoverBullAttemptMonitoringController> attemptMonitoring({
    Future<RecoverBullAttemptsSnapshot?> Function({
      required String? etag,
      required List<String> backupDigests,
    })?
    poll,
  }) async {
    final db = await lifecycle._openDatabase(
      config.databasePath,
      initialPermissionGranted: config.initialPermissionGranted,
    );
    final row = await db.select(db.recoverbullState).getSingle();
    return RecoverBullAttemptMonitoring(
      RecoverBullAttemptMonitoringStore(db),
      enabled: row.attemptMonitoringEnabled,
      poll: poll,
    );
  }
}

/// The result of a recovery operation, excluding recovered secret material.
@immutable
final class RecoverBullRecoveryResult {
  final bool restored;

  const RecoverBullRecoveryResult({required this.restored});
}
