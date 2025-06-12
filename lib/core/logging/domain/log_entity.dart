import 'package:freezed_annotation/freezed_annotation.dart';

part 'log_entity.freezed.dart';

enum LogLevel { trace, debug, info, error }

@freezed
sealed class LogEntity with _$LogEntity {
  const factory LogEntity.new({
    required LogLevel level,
    required String message,
    required String logger,
    Map<String, dynamic>? context,
    // Only used for LogLevel.error
    Object? exception,
    StackTrace? stackTrace,
  }) = NewLogEntity;

  const factory LogEntity.complete({
    required LogLevel level,
    required String message,
    required String logger,
    Map<String, dynamic>? context,
    Object? exception,
    StackTrace? stackTrace,
    required DateTime timestamp,
    required String appVersion,
  }) = CompleteLogEntity;
  const LogEntity._();
}
