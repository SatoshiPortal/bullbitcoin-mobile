import 'package:bb_mobile/core/logging/domain/entities/log.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'log_model.freezed.dart';
part 'log_model.g.dart';

@freezed
sealed class LogModel with _$LogModel {
  const factory LogModel.generic({
    required String message,
    required DateTime timestamp,
    required String logger,
    required LogLevel level,
    String? appVersion,
    Map<String, dynamic>? context,
  }) = GenericLogModel;

  const factory LogModel.error({
    @Default(LogLevel.error) LogLevel level,
    required String message,
    required DateTime timestamp,
    required String logger,
    required String exception,
    String? appVersion,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) = ErrorLogModel;

  factory LogModel.fromJson(Map<String, Object?> json) =>
      _$LogModelFromJson(json);
}
