import 'package:bb_mobile/core/logging/data/datasources/log_datasource.dart';
import 'package:bb_mobile/core/logging/data/models/log_model.dart';
import 'package:bb_mobile/core/logging/domain/entities/log.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LogRepository {
  final LogDatasource _logDatasource;
  PackageInfo? _cachedPackageInfo;
  //final SettingsDatasource _settingsDatasource;

  LogRepository({
    required LogDatasource logDatasource,
    //required SettingsDatasource settingsDatasource,
  }) : _logDatasource = logDatasource;
  //_settingsDatasource = settingsDatasource;

  Future<void> logTrace({
    required String message,
    required String logger,
    Map<String, dynamic>? context,
  }) async {
    final log = LogModel.generic(
      message: message,
      timestamp: DateTime.now().toUtc(),
      logger: logger,
      appVersion: await _appVersion,
      context: context,
      level: LogLevel.trace,
    );
    await _logDatasource.addLog(log);
  }

  Future<void> logDebug({
    required String message,
    required String logger,
    Map<String, dynamic>? context,
  }) async {
    final log = LogModel.generic(
      message: message,
      timestamp: DateTime.now().toUtc(),
      logger: logger,
      appVersion: await _appVersion,
      context: context,
      level: LogLevel.debug,
    );
    await _logDatasource.addLog(log);
  }

  Future<void> logInfo({
    required String message,
    required String logger,
    Map<String, dynamic>? context,
  }) async {
    final log = LogModel.generic(
      message: message,
      timestamp: DateTime.now().toUtc(),
      logger: logger,
      appVersion: await _appVersion,
      context: context,
      level: LogLevel.info,
    );

    await _logDatasource.addLog(log);
  }

  Future<void> logError({
    required String message,
    required String logger,
    required Object exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    final log = LogModel.error(
      message: message,
      timestamp: DateTime.now().toUtc(),
      logger: logger,
      exception: exception.toString(),
      stackTrace: stackTrace?.toString(),
      appVersion: await _appVersion,
      context: context,
    );

    await _logDatasource.addLog(log);
  }

  Future<void> truncateLogs(DateTime from, DateTime until) =>
      _logDatasource.truncateLogs(from: from, until: until);

  Future<void> clearLogs() => _logDatasource.clearLogs();

  Future<String> get _appVersion async {
    try {
      _cachedPackageInfo ??= await PackageInfo.fromPlatform();
      final info = _cachedPackageInfo!;
      return '${info.version}+${info.buildNumber}';
    } catch (e) {
      return 'unknown';
    }
  }
}
