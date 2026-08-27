import 'package:bb_mobile/core/utils/logger.dart';

abstract interface class LoggerLogsDatasource {
  Future<List<String>> read();

  Future<void> delete();
}

class LoggerLogsDatasourceImpl implements LoggerLogsDatasource {
  final Logger _logger;

  const LoggerLogsDatasourceImpl(this._logger);

  @override
  Future<List<String>> read() => _logger.readLogs();

  @override
  Future<void> delete() => _logger.deleteLogs();
}
