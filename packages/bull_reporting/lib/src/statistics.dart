import 'dart:async';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'metrics/daily_active.dart';
import 'metrics/statistics_consent.dart';
import 'metrics/statistics_transport.dart';

/// Process-wide statistics authority. No producer can bypass its consent gate.
final class Statistics {
  static final Statistics instance = Statistics._();

  final StatisticsConsent _consent = StatisticsConsent(
    FileStatisticsConsentStore(() async {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}/statistics_consent.v1');
    }),
  );
  StatisticsTransport? _transport;
  DailyActiveInstallations? _daily;
  bool _foreground = false;
  bool? _failedChoice;

  Statistics._() {
    _consent.changes.listen(_applyConsent);
  }

  bool get enabled => _consent.enabled;
  bool? get failedChoice => _failedChoice;
  Stream<bool> get changes => _consent.changes;

  Future<bool> initialize() => _consent.initialize();

  /// A false result means the choice could not be persisted.
  Future<bool> setEnabled(bool enabled) async {
    final saved = await _consent.setEnabled(enabled);
    _failedChoice = saved ? null : enabled;
    return saved;
  }

  /// Starts the producer with a build-configured endpoint and environment.
  Future<void> start({required String dsn, required String environment}) async {
    final directory = await getApplicationSupportDirectory();
    final info = await PackageInfo.fromPlatform();
    final transport = StatisticsTransport(
      dsn,
      '${info.version}+${info.buildNumber}',
      environment,
    );
    final daily = DailyActiveInstallations(
      FileActiveDayStore(File('${directory.path}/statistics_active_day.v1')),
      transport.installationActive,
    );
    _daily?.setConsent(false);
    _transport?.updateConsent(false);
    _transport = transport;
    _daily = daily;
    await _consent.initialize();
    _applyConsent(_consent.enabled);
    daily.setForeground(_foreground);
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _daily?.setForeground(foreground);
  }

  void _applyConsent(bool enabled) {
    final transport = _transport;
    transport?.updateConsent(enabled);
    _daily?.setConsent(enabled && (transport?.available ?? false));
  }
}
