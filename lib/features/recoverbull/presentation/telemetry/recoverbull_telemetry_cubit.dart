import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_telemetry_alert.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/acknowledge_telemetry_alert_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_backup_telemetry_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/is_recoverbull_telemetry_enabled_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/record_local_attempt_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/register_monitored_backup_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/presentation/telemetry/recoverbull_telemetry_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// App-scoped holder for the advisory brute-force telemetry alerts.
///
/// Registered as a lazy singleton: the alerts survive across screens. Every
/// method is fail-safe — telemetry never blocks startup, recovery, or any
/// user flow, and a failure degrades to silence.
///
/// Trust model: telemetry is advisory. The server cannot distinguish an
/// attacker from the user or another of the user's devices, and a
/// compromised server can fabricate or suppress counters. The UI warns,
/// never acts automatically.
class RecoverbullTelemetryCubit extends Cubit<RecoverbullTelemetryState> {
  final CheckBackupTelemetryUsecase _checkBackupTelemetryUsecase;
  final RecordLocalAttemptUsecase _recordLocalAttemptUsecase;
  final RegisterMonitoredBackupUsecase _registerMonitoredBackupUsecase;
  final AcknowledgeTelemetryAlertUsecase _acknowledgeTelemetryAlertUsecase;
  final IsRecoverbullTelemetryEnabledUsecase _isEnabledUsecase;

  RecoverbullTelemetryCubit({
    required this._checkBackupTelemetryUsecase,
    required this._recordLocalAttemptUsecase,
    required this._registerMonitoredBackupUsecase,
    required this._acknowledgeTelemetryAlertUsecase,
    required this._isEnabledUsecase,
  }) : super(const RecoverbullTelemetryState());

  /// Cold-launch trigger: runs the snapshot check when the feature flag is
  /// on. Unawaited by the caller; never throws, never blocks startup.
  Future<void> checkOnColdLaunch() async {
    try {
      if (!await _isEnabledUsecase.execute()) return;
      switch (await _checkBackupTelemetryUsecase.execute()) {
        case Ok(:final value):
          if (value.isNotEmpty) _mergeAlerts(value);
        case Err():
          break; // silent: telemetry failures degrade to silence
      }
    } catch (e) {
      log.warning('telemetry cold-launch check failed: $e');
    }
  }

  /// Records one of the user's own key-server operations (store/fetch/trash)
  /// and surfaces an immediate suspicious-activity alert when the server's
  /// counters exceed this device's own operations.
  Future<void> recordLocalAttempt({
    required String backupIdHex,
    KeyServerAttemptStatus? attemptStatus,
  }) async {
    try {
      if (!await _isEnabledUsecase.execute()) return;
      switch (await _recordLocalAttemptUsecase.execute(
        backupIdHex: backupIdHex,
        attemptStatus: attemptStatus,
      )) {
        case Ok(:final value):
          if (value != null) _mergeAlerts([value]);
        case Err():
          break;
      }
    } catch (e) {
      log.warning('telemetry record attempt failed: $e');
    }
  }

  /// Registers a backup as monitored after a `/store`, without counting an
  /// attempt: the server does not count stores, so counting one locally would
  /// inflate the baseline and mask one attacker probe per window.
  Future<void> registerMonitoredBackup({required String backupIdHex}) async {
    try {
      if (!await _isEnabledUsecase.execute()) return;
      await _registerMonitoredBackupUsecase.execute(backupIdHex: backupIdHex);
    } catch (e) {
      log.warning('telemetry register backup failed: $e');
    }
  }

  /// The user's own fetch hit the targeted per-identifier lockout: someone
  /// may be probing or griefing this backup.
  Future<void> reportTargetedLockout({required String backupIdHex}) async {
    try {
      if (!await _isEnabledUsecase.execute()) return;
      final backupIdHash = recoverbull.attemptsIdHashFromHex(
        backupIdHex.replaceAll(RegExp(r'\s'), ''),
      );
      _mergeAlerts([TargetedLockoutAlert(backupIdHash: backupIdHash)]);
    } catch (e) {
      log.warning('telemetry report lockout failed: $e');
    }
  }

  /// Dismisses the alerts for a backup and remembers the acknowledgement so
  /// multi-device false positives do not train the user to ignore alerts.
  Future<void> acknowledge({required String backupIdHash}) async {
    try {
      await _acknowledgeTelemetryAlertUsecase.execute(
        backupIdHash: backupIdHash,
      );
    } catch (e) {
      log.warning('telemetry acknowledge failed: $e');
    }
    emit(
      state.copyWith(
        alerts: state.alerts
            .where((a) => _alertHash(a) != backupIdHash)
            .toList(),
      ),
    );
  }

  /// Dismisses one alert. Backup-scoped alerts also record the
  /// acknowledgement; service-pressure and soft notices — which carry no
  /// backup — are simply cleared, so every surfaced alert is dismissible.
  Future<void> dismiss(RecoverbullTelemetryAlert alert) async {
    final hash = _alertHash(alert);
    if (hash != null) {
      await acknowledge(backupIdHash: hash);
      return;
    }
    emit(
      state.copyWith(
        alerts: state.alerts
            .where((a) => _alertIdentity(a) != _alertIdentity(alert))
            .toList(),
      ),
    );
  }

  void _mergeAlerts(List<RecoverbullTelemetryAlert> newAlerts) {
    final merged = [...state.alerts];
    for (final alert in newAlerts) {
      // dedup on the full identity: the service-pressure KIND is part of it,
      // otherwise a global-429 notice would swallow a later capacity-503 one
      final exists = merged.any(
        (a) => _alertIdentity(a) == _alertIdentity(alert),
      );
      if (!exists) merged.add(alert);
    }
    emit(state.copyWith(alerts: merged));
  }

  static String? _alertHash(RecoverbullTelemetryAlert alert) {
    return switch (alert) {
      SuspiciousActivityAlert(:final backupIdHash) => backupIdHash,
      TargetedLockoutAlert(:final backupIdHash) => backupIdHash,
      _ => null,
    };
  }

  /// The dedup identity of an alert: its type, plus the backup it concerns or
  /// the service-pressure kind it reports.
  static String _alertIdentity(RecoverbullTelemetryAlert alert) {
    return switch (alert) {
      SuspiciousActivityAlert(:final backupIdHash) =>
        'suspicious:$backupIdHash',
      TargetedLockoutAlert(:final backupIdHash) => 'lockout:$backupIdHash',
      ServicePressureAlert(:final kind) => 'pressure:${kind.name}',
      TelemetryUnavailableAlert() => 'unavailable',
      CountersWipedAlert() => 'wiped',
    };
  }
}
