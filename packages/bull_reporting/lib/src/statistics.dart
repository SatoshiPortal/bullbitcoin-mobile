import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'metrics/daily_active.dart';
import 'metrics/statistics_consent.dart';
import 'metrics/statistics_transport.dart';
import 'metrics/statistics_network.dart';
import 'metrics/statistics_runtime.dart';

/// Process-wide statistics authority. No producer can bypass its consent gate.
final class Statistics {
  static final Statistics instance = Statistics._();

  final StatisticsConsent _consent = StatisticsConsent(
    FileStatisticsConsentStore(() async {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}/statistics_consent.v1');
    }),
  );
  StatisticsRuntime? _runtime;
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

  /// Starts statistics only in release mode with a known mainnet wallet.
  Future<void> start({
    required String dsn,
    required StatisticsNetwork network,
  }) async {
    _runtime?.dispose();
    _runtime = null;
    if (!kReleaseMode) return;
    final directory = await getApplicationSupportDirectory();
    final info = await PackageInfo.fromPlatform();
    late final StatisticsRuntime runtime;
    final transport = StatisticsTransport(
      dsn,
      '${info.version}+${info.buildNumber}',
      'mainnet',
      () => runtime.canSend(),
    );
    runtime = StatisticsRuntime(
      network,
      transport,
      FileActiveDayStore(File('${directory.path}/statistics_active_day.v1')),
      kReleaseMode,
    );
    _runtime = runtime;
    await _consent.initialize();
    _applyConsent(_consent.enabled);
    runtime.setForeground(_foreground);
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _runtime?.setForeground(foreground);
  }

  void _applyConsent(bool enabled) {
    _runtime?.setConsent(enabled);
  }
}
