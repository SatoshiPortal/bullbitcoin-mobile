import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class ServiceStatusState with _$ServiceStatusState {
  const factory ServiceStatusState({
    @Default(AllServicesStatus()) AllServicesStatus serviceStatus,
    @Default(false) bool isLoading,
    @Default(null) String? error,
  }) = _ServiceStatusState;

  const ServiceStatusState._();
}
