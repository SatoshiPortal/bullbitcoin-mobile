import 'package:freezed_annotation/freezed_annotation.dart';

part 'log.freezed.dart';

enum LogLevel { trace, debug, info, error }

@freezed
sealed class Log with _$Log {
  const factory Log.new({
    required LogLevel level,
    required String message,
    required String logger,
    Map<String, dynamic>? context,
    // Only used for LogLevel.error
    Object? exception,
    StackTrace? stackTrace,
  }) = NewLog;
  const factory Log.complete({
    required LogLevel level,
    required String message,
    required String logger,
    Map<String, dynamic>? context,
    Object? exception,
    StackTrace? stackTrace,
    required DateTime timestamp,
    required String appVersion,
  }) = CompleteLog;
  const Log._();
}
