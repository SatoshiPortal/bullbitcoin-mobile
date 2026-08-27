import 'package:bull_logger/bull_logger.dart';

abstract interface class LoggerLogsDatasource {
  Future<List<String>> read();

  Future<void> delete();

  Future<String?> currentDiagnosticLogLine();

  Future<List<String>> createLogBundleLines(List<String> lines);
}

class LoggerLogsDatasourceImpl implements LoggerLogsDatasource {
  final Logger _logger;

  const LoggerLogsDatasourceImpl(this._logger);

  @override
  Future<List<String>> read() => _logger.readLogs();

  @override
  Future<void> delete() => _logger.deleteLogs();

  @override
  Future<String?> currentDiagnosticLogLine() =>
      _logger.currentDiagnosticLogLine();

  @override
  Future<List<String>> createLogBundleLines(List<String> lines) =>
      _logger.createLogBundleLines(lines);
}
