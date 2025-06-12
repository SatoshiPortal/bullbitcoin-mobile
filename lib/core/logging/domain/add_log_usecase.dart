import 'package:bb_mobile/core/logging/data/log_repository.dart';
import 'package:bb_mobile/core/logging/domain/log_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart' as logging;

class AddLogUsecase {
  final LogRepository _logRepository;

  AddLogUsecase({required LogRepository logRepository})
    : _logRepository = logRepository;

  Future<void> execute(NewLogEntity log) {
    try {
      switch (log.level) {
        case LogLevel.trace:
          return _logRepository.logTrace(
            message: log.message,
            logger: log.logger,
            context: log.context,
          );
        case LogLevel.debug:
          return _logRepository.logDebug(
            message: log.message,
            logger: log.logger,
            context: log.context,
          );
        case LogLevel.info:
          return _logRepository.logInfo(
            message: log.message,
            logger: log.logger,
            context: log.context,
          );
        case LogLevel.error:
          return _logRepository.logError(
            message: log.message,
            logger: log.logger,
            exception: log.exception ?? Exception('Missing exception'),
            stackTrace: log.stackTrace,
            context: log.context,
          );
      }
    } catch (e) {
      logging.log.info('[AddLogUsecase]: $e');
      throw AddLogUsecaseException('$e');
    }
  }
}

class AddLogUsecaseException implements Exception {
  final String message;

  AddLogUsecaseException(this.message);

  @override
  String toString() => '[AddLogUsecase] $message';
}
