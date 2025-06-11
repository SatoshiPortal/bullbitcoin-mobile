import 'package:bb_mobile/core/logging/data/repositories/log_repository.dart';
import 'package:bb_mobile/core/logging/domain/entities/log.dart';
import 'package:flutter/foundation.dart';

class AddLogUsecase {
  final LogRepository _logRepository;

  AddLogUsecase({required LogRepository logRepository})
    : _logRepository = logRepository;

  Future<void> execute(NewLog log) {
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
      debugPrint('[AddLogUsecase]: $e');
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
