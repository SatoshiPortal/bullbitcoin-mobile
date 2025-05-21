import 'package:bb_mobile/core/logging/domain/entities/log.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'log_model.freezed.dart';
part 'log_model.g.dart';

@freezed
sealed class LogModel with _$LogModel {
  const factory LogModel.trace({
    required String message,
    required DateTime timestamp,
    required String logger,
    String? appVersion,
    Map<String, dynamic>? context,
  }) = TraceLogModel;
  const factory LogModel.debug({
    required String message,
    required DateTime timestamp,
    required String logger,
    String? appVersion,
    Map<String, dynamic>? context,
  }) = DebugLogModel;
  const factory LogModel.info({
    required String message,
    required DateTime timestamp,
    required String logger,
    String? appVersion,
    Map<String, dynamic>? context,
  }) = InfoLogModel;
  const factory LogModel.error({
    required String message,
    required DateTime timestamp,
    required String logger,
    String? appVersion,
    Map<String, dynamic>? context,
    required String exception,
    String? stackTrace,
  }) = ErrorLogModel;
  const LogModel._();

  factory LogModel.fromJson(Map<String, Object?> json) =>
      _$LogModelFromJson(json);

  LogLevel get level => switch (this) {
    DebugLogModel() => LogLevel.debug,
    InfoLogModel() => LogLevel.info,
    ErrorLogModel() => LogLevel.error,
    TraceLogModel() => LogLevel.trace,
  };
}
