import '../domain/service_status.dart';
import '../domain/status_check_failure.dart';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_status_state.freezed.dart';

@freezed
sealed class ServiceStatusState with _$ServiceStatusState {
  const factory ServiceStatusState({
    @Default(AllServicesStatus()) AllServicesStatus serviceStatus,
    @Default(false) bool isLoading,
    @Default(null) StatusCheckFailure? failure,
  }) = _ServiceStatusState;

  const ServiceStatusState._();
}
