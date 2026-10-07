import 'dart:async';

import 'package:meta/meta.dart';
import 'package:bull_logger/bull_logger.dart';

import '../attempt_monitoring/recoverbull_attempt_monitoring.dart';
import '../domain/usecases/check_backup_attempt_monitoring_usecase.dart';
import '../domain/entities/attempt_alert.dart' as domain_alert;
import '../domain/recoverbull_attempt_alert_port.dart';
import '../domain/recoverbull_server_url.dart';

export '../database/recoverbull_lifecycle.dart' show RecoverBullLifecycle;
export '../domain/entities/recoverbull_server_settings.dart'
    show RecoverBullServerSettings;
export '../domain/entities/recoverbull_status.dart' show RecoverBullStatus;
export '../domain/recoverbull_server_url.dart'
    show validateRecoverBullServerUrl, recoverBullDefaultServerUrl;
export '../domain/recoverbull_timing.dart' show RecoverBullTiming;

@immutable
final class RecoverBullConfig {
  final String databasePath;
  final Uri? defaultServer;
  final Uri? initialServerUrlOverride;
  final bool initialPermissionGranted;

  const RecoverBullConfig({
    required this.databasePath,
    this.defaultServer,
    this.initialServerUrlOverride,
    this.initialPermissionGranted = false,
  });

  Uri get effectiveDefaultServer =>
      defaultServer ?? Uri.parse(recoverBullDefaultServerUrl);
}

enum RecoverBullHealth { online, offline, timeout, temporarilyUnavailable }

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
  identifierSaturation,
  unavailable,
}

final class RecoverBullAttemptAlert {
  final RecoverBullAttemptAlertKind kind;
  final String? backupReference;

  /// Opaque complete backup digest used to correlate related event alerts.
  /// Never display or log this value.
  final String correlationId;

  /// Stable identity of this particular event, used for deduplication and
  /// acknowledgement. This is not the backup correlation identifier.
  final String identity;
  final int? observedTotal;
  final int? expectedTotal;
  final DateTime? windowStartedAt;

  RecoverBullAttemptAlert(this.kind)
    : backupReference = null,
      correlationId = kind.name,
      identity = kind.name,
      observedTotal = null,
      expectedTotal = null,
      windowStartedAt = null;

  const RecoverBullAttemptAlert._(
    this.kind,
    this.correlationId,
    this.identity, {
    this.backupReference,
    this.observedTotal,
    this.expectedTotal,
    this.windowStartedAt,
  });

  factory RecoverBullAttemptAlert.suspiciousActivity({
    required String backupReference,
    required String correlationId,
    required int observedTotal,
    required int expectedTotal,
    required DateTime windowStartedAt,
  }) => RecoverBullAttemptAlert._(
    RecoverBullAttemptAlertKind.suspiciousActivity,
    correlationId,
    's:$correlationId:${windowStartedAt.toUtc().microsecondsSinceEpoch}',
    backupReference: backupReference,
    observedTotal: observedTotal,
    expectedTotal: expectedTotal,
    windowStartedAt: windowStartedAt,
  );

  factory RecoverBullAttemptAlert.targetedLockout({
    required String backupReference,
    required String correlationId,
  }) => RecoverBullAttemptAlert._(
    RecoverBullAttemptAlertKind.targetedLockout,
    correlationId,
    'l:$correlationId',
    backupReference: backupReference,
  );
}

abstract interface class RecoverBullAttemptMonitoringController {
  Future<List<RecoverBullAttemptAlert>> check();
  Future<List<RecoverBullAttemptAlert>> checkOnForeground();
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
  final LogSink? _log;
  final Future<RecoverBullAttemptsSnapshot?> Function({
    required String? etag,
    required List<String> backupDigests,
  })?
  _poll;
  bool _enabled;
  final StreamController<List<RecoverBullAttemptAlert>> _alertUpdates =
      StreamController.broadcast();
  final List<RecoverBullAttemptAlert> _visibleAlerts = [];
  final Set<String> _acknowledgedIdentities = {};
  Future<List<RecoverBullAttemptAlert>>? _checkInFlight;
  bool _forceRefreshInFlight = false;

  RecoverBullAttemptMonitoring(
    this._store, {
    this._enabled = false,
    this._poll,
    LogSink? log,
    Set<String> acknowledged = const {},
  })
    // `log` is intentionally public-facing while the stored sink stays private.
    // ignore: prefer_initializing_formals
    : _log = log {
    _acknowledgedIdentities.addAll(acknowledged);
  }

  /// Opens the controller with the acknowledgements recorded by previous
  /// sessions, so a dismissed alert is not raised again for the same window.
  static Future<RecoverBullAttemptMonitoring> open(
    RecoverBullAttemptMonitoringStore store, {
    bool enabled = false,
    Future<RecoverBullAttemptsSnapshot?> Function({
      required String? etag,
      required List<String> backupDigests,
    })?
    poll,
    LogSink? log,
  }) async => RecoverBullAttemptMonitoring(
    store,
    enabled: enabled,
    poll: poll,
    log: log,
    acknowledged: await store.acknowledgedAlertIdentities(),
  );

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
  Future<List<RecoverBullAttemptAlert>> check() =>
      _runCheck(forceRefresh: false);

  Future<List<RecoverBullAttemptAlert>> _runCheck({
    required bool forceRefresh,
  }) async {
    while (true) {
      final active = _checkInFlight;
      if (active == null) break;
      if (!forceRefresh || _forceRefreshInFlight) return active;
      await active;
    }
    late final Future<List<RecoverBullAttemptAlert>> future;
    future = _performCheck(forceRefresh: forceRefresh).whenComplete(() {
      if (identical(_checkInFlight, future)) {
        _checkInFlight = null;
        _forceRefreshInFlight = false;
      }
    });
    _checkInFlight = future;
    _forceRefreshInFlight = forceRefresh;
    return future;
  }

  Future<List<RecoverBullAttemptAlert>> _performCheck({
    required bool forceRefresh,
  }) async {
    if (!_enabled || _poll == null) return const [];
    try {
      final alerts =
          (await CheckBackupAttemptMonitoringUsecase(
                store: _store,
                remote: _CallbackAttemptMonitoringRemote(_poll),
              ).execute(forceRefresh: forceRefresh))
              .map(_publicAlert)
              .where(
                (alert) => !_acknowledgedIdentities.contains(alert.identity),
              )
              .toList(growable: false);
      _log?.fine(
        'recoverbull.attempts.monitoring.succeeded '
        'alert_count=${alerts.length} force_refresh=$forceRefresh',
      );
      for (final alert in alerts) {
        final alreadyVisible = _visibleAlerts.any(
          (visible) =>
              visible.kind == alert.kind && visible.identity == alert.identity,
        );
        if (!alreadyVisible) _visibleAlerts.add(alert);
      }
      if (!_alertUpdates.isClosed) {
        _alertUpdates.add(List.unmodifiable(_visibleAlerts));
      }
      return alerts;
    } catch (error) {
      _log?.warning(
        'recoverbull.attempts.monitoring.failed '
        'error_type=${error.runtimeType}',
      );
      final unavailable = _publicAlert(
        const domain_alert.AttemptMonitoringUnavailableAlert(since: null),
      );
      if (!_visibleAlerts.any(
        (alert) => alert.identity == unavailable.identity,
      )) {
        _visibleAlerts.add(unavailable);
        if (!_alertUpdates.isClosed) {
          _alertUpdates.add(List.unmodifiable(_visibleAlerts));
        }
      }
      return [unavailable];
    }
  }

  @override
  void publish(domain_alert.AttemptAlert alert) {
    final publicAlert = _publicAlert(alert);
    if (_acknowledgedIdentities.contains(publicAlert.identity)) return;
    final alreadyVisible = _visibleAlerts.any(
      (visible) =>
          visible.kind == publicAlert.kind &&
          visible.identity == publicAlert.identity,
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
          backupIdHash,
          's:$backupIdHash:${windowStartedAt.toUtc().microsecondsSinceEpoch}',
          backupReference: _safeReference(backupIdHash),
          observedTotal: observedTotal,
          expectedTotal: expectedTotal,
          windowStartedAt: windowStartedAt,
        ),
      domain_alert.TargetedLockoutAlert(:final backupIdHash) =>
        RecoverBullAttemptAlert._(
          RecoverBullAttemptAlertKind.targetedLockout,
          backupIdHash,
          'l:$backupIdHash',
          backupReference: _safeReference(backupIdHash),
        ),
      domain_alert.ServicePressureAlert(:final kind) =>
        RecoverBullAttemptAlert._(
          kind == domain_alert.ServicePressureKind.identifierSaturation
              ? RecoverBullAttemptAlertKind.identifierSaturation
              : RecoverBullAttemptAlertKind.servicePressure,
          'service:${kind.name}',
          'p:$kind',
        ),
      domain_alert.AttemptMonitoringUnavailableAlert() =>
        RecoverBullAttemptAlert._(
          RecoverBullAttemptAlertKind.unavailable,
          'unavailable',
          'u',
        ),
    };
  }

  @override
  Future<List<RecoverBullAttemptAlert>> checkOnForeground() =>
      _runCheck(forceRefresh: true);

  @override
  Future<void> acknowledge(RecoverBullAttemptAlert alert) async {
    _acknowledgedIdentities.add(alert.identity);
    // Only a window-scoped identity is durable: a lockout, pressure or
    // unavailability alert has none and must be able to alert again later.
    if (alert.windowStartedAt != null) {
      try {
        await _store.acknowledgeAlert(
          alert.identity,
          at: DateTime.now().toUtc(),
        );
      } catch (error) {
        _log?.warning(
          'recoverbull.attempts.acknowledge.failed '
          'error_type=${error.runtimeType}',
        );
      }
    }
    _visibleAlerts.removeWhere(
      (candidate) => candidate.identity == alert.identity,
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

/// The result of a recovery operation, excluding recovered secret material.
@immutable
final class RecoverBullRecoveryResult {
  final bool restored;

  const RecoverBullRecoveryResult({required this.restored});
}
