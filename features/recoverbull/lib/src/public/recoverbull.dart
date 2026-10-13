import '../domain/entities/attempt_monitoring_state.dart';
import '../domain/entities/monitored_backup.dart';
import '../domain/entities/recoverbull_monitoring_status.dart';
export '../domain/entities/recoverbull_monitoring_status.dart';
import '../domain/recoverbull_monitoring_settings_port.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/usecases/load_recoverbull_monitoring_status_usecase.dart';
import '../domain/usecases/change_recoverbull_monitoring_enabled_usecase.dart';
export '../domain/usecases/load_recoverbull_monitoring_status_usecase.dart';
export '../domain/usecases/change_recoverbull_monitoring_enabled_usecase.dart';
import 'package:primitives/primitives.dart';
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:bull_logger/bull_logger.dart';

import '../domain/entities/attempt_monitoring_snapshot.dart';
import '../domain/repositories/recoverbull_attempt_monitoring_repository.dart';
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
  final RecoverBullAttemptMonitoringRepository _store;
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
    RecoverBullAttemptMonitoringRepository store, {
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
    acknowledged: (await store.acknowledgedAlertIdentities()).fold(
      (value) => value,
      (_) => const <String>{},
    ),
  );

  @override
  bool get enabled => _enabled;

  Future<Result<RecoverBullMonitoringStatus, RecoverBullFailure>>
  statusResult() async {
    final stateResult = await _store.state();
    if (stateResult case Err(:final failure)) return Err(failure);
    final rowsResult = await _store.monitoredBackups();
    if (rowsResult case Err(:final failure)) return Err(failure);
    final state =
        (stateResult as Ok<AttemptMonitoringState, RecoverBullFailure>).value;
    final rows =
        (rowsResult as Ok<List<MonitoredBackup>, RecoverBullFailure>).value;
    return Ok(
      RecoverBullMonitoringStatus(
        enabled: state.attemptMonitoringEnabled,
        serverUnsupported: state.attemptsUnsupportedAt(DateTime.now().toUtc()),
        monitoredCount: rows.length,
        lastSuccessfulCheck: state.lastSuccessfulCheckAt,
      ),
    );
  }

  @override
  Future<RecoverBullMonitoringStatus> status() async =>
      (await statusResult()).fold(
        (value) => value,
        (_) => RecoverBullMonitoringStatus(
          enabled: _enabled,
          monitoredCount: 0,
          lastSuccessfulCheck: null,
        ),
      );

  @override
  Stream<List<RecoverBullAttemptAlert>> get alerts async* {
    yield List.unmodifiable(_visibleAlerts);
    yield* _alertUpdates.stream;
  }

  Future<Result<RecoverBullMonitoringStatus, RecoverBullFailure>>
  setEnabledResult(bool enabled) async {
    final result = await _store.setEnabled(enabled);
    if (result case Err(:final failure)) return Err(failure);
    _enabled = enabled;
    return statusResult();
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final result = await setEnabledResult(enabled);
    if (result case Err()) _log?.warning('recoverbull.attempts.enable.failed');
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
      final result = await CheckBackupAttemptMonitoringUsecase(
        store: _store,
        remote: _CallbackAttemptMonitoringRemote(_poll),
      ).execute(forceRefresh: forceRefresh);
      final alerts = switch (result) {
        Ok(:final value) =>
          value
              .map(_publicAlert)
              .where(
                (alert) => !_acknowledgedIdentities.contains(alert.identity),
              )
              .toList(growable: false),
        Err() => [
          _publicAlert(
            const domain_alert.AttemptMonitoringUnavailableAlert(since: null),
          ),
        ],
      };
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
    } on Exception catch (error) {
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
        final result = await _store.acknowledgeAlert(
          alert.identity,
          at: DateTime.now().toUtc(),
        );
        if (result case Err()) {
          _log?.warning('recoverbull.attempts.acknowledge.failed');
        }
      } on Exception catch (error) {
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

/// Settings consumers call domain usecases while the controller stays public.
({
  LoadRecoverBullMonitoringStatusUsecase load,
  ChangeRecoverBullMonitoringEnabledUsecase change,
})
createRecoverBullMonitoringSettingsUsecases(
  RecoverBullAttemptMonitoringController controller, {
  required LogSink log,
}) {
  final port = _ControllerMonitoringSettingsPort(controller, log);
  return (
    load: LoadRecoverBullMonitoringStatusUsecase(port),
    change: ChangeRecoverBullMonitoringEnabledUsecase(port),
  );
}

final class _ControllerMonitoringSettingsPort
    implements RecoverBullMonitoringSettingsPort {
  final RecoverBullAttemptMonitoringController controller;
  final LogSink log;

  const _ControllerMonitoringSettingsPort(this.controller, this.log);

  @override
  Future<Result<RecoverBullMonitoringStatus, RecoverBullFailure>>
  status() async {
    if (controller case RecoverBullAttemptMonitoring monitor) {
      return monitor.statusResult();
    }
    try {
      return Ok(await controller.status());
    } on Exception catch (error) {
      log.warning(
        'recoverbull.monitoring.settings.load_failed error_type=${error.runtimeType}',
      );
      return const Err(
        RecoverBullUnexpectedFailure('Monitoring settings unavailable'),
      );
    }
  }

  @override
  Future<Result<RecoverBullMonitoringStatus, RecoverBullFailure>> setEnabled(
    bool enabled,
  ) async {
    if (controller case RecoverBullAttemptMonitoring monitor) {
      return monitor.setEnabledResult(enabled);
    }
    try {
      await controller.setEnabled(enabled);
      return status();
    } on Exception catch (error) {
      log.warning(
        'recoverbull.monitoring.settings.save_failed error_type=${error.runtimeType}',
      );
      return const Err(
        RecoverBullUnexpectedFailure('Monitoring settings unavailable'),
      );
    }
  }
}
