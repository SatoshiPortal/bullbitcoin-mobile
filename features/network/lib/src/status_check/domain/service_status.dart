import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_status.freezed.dart';

/// [disabled]: the service is intentionally turned off by the user (e.g.
/// payjoin off in settings), so it is neither reachable-checked nor a
/// problem — distinct from [unknown] (not checked / indeterminate).
enum ServiceStatus { online, offline, unknown, disabled }

@freezed
sealed class ServiceStatusInfo with _$ServiceStatusInfo {
  const factory ServiceStatusInfo({
    required ServiceStatus status,
    DateTime? lastChecked,
  }) = _ServiceStatusInfo;

  const ServiceStatusInfo._();

  bool get isOnline => status == ServiceStatus.online;
  bool get isOffline => status == ServiceStatus.offline;
  bool get isUnknown => status == ServiceStatus.unknown;
  bool get isDisabled => status == ServiceStatus.disabled;
}

@freezed
sealed class AllServicesStatus with _$AllServicesStatus {
  const factory AllServicesStatus({
    @Default(ServiceStatusInfo(status: ServiceStatus.unknown))
    ServiceStatusInfo internetConnection,
    @Default(ServiceStatusInfo(status: ServiceStatus.unknown))
    ServiceStatusInfo bitcoinElectrum,
    @Default(ServiceStatusInfo(status: ServiceStatus.unknown))
    ServiceStatusInfo liquidElectrum,
    @Default(ServiceStatusInfo(status: ServiceStatus.unknown))
    ServiceStatusInfo payjoin,
    @Default(ServiceStatusInfo(status: ServiceStatus.unknown))
    ServiceStatusInfo pricer,
    @Default(ServiceStatusInfo(status: ServiceStatus.unknown))
    ServiceStatusInfo mempool,
    @Default(ServiceStatusInfo(status: ServiceStatus.unknown))
    ServiceStatusInfo tor,
    @Default(ServiceStatusInfo(status: ServiceStatus.unknown))
    ServiceStatusInfo recoverbull,
    @Default(null) DateTime? lastChecked,
  }) = _AllServicesStatus;

  const AllServicesStatus._();

  bool get allServicesOnline =>
      internetConnection.isOnline &&
      bitcoinElectrum.isOnline &&
      liquidElectrum.isOnline &&
      // Payjoin is opt-in: disabled is not a fault (see _checkPayjoinService).
      (payjoin.isOnline || payjoin.isDisabled) &&
      pricer.isOnline &&
      mempool.isOnline &&
      (tor.isOnline || tor.isUnknown) &&
      (recoverbull.isOnline || recoverbull.isUnknown);

  bool get hasAnyServiceOffline => !allServicesOnline;
}
