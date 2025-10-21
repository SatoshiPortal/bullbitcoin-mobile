import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_status.freezed.dart';

enum ServiceStatus { online, offline, unknown }

@freezed
sealed class ServiceStatusInfo with _$ServiceStatusInfo {
  const factory ServiceStatusInfo({
    required ServiceStatus status,
    required String name,
    DateTime? lastChecked,
  }) = _ServiceStatusInfo;

  const ServiceStatusInfo._();

  bool get isOnline => status == ServiceStatus.online;
  bool get isOffline => status == ServiceStatus.offline;
  bool get isUnknown => status == ServiceStatus.unknown;
}

@freezed
sealed class AllServicesStatus with _$AllServicesStatus {
  const factory AllServicesStatus({
    required ServiceStatusInfo internetConnection,
    required ServiceStatusInfo bitcoinElectrum,
    required ServiceStatusInfo liquidElectrum,
    required ServiceStatusInfo boltz,
    required ServiceStatusInfo payjoin,
    required ServiceStatusInfo pricer,
    required ServiceStatusInfo mempool,
    @Default(
      ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Recoverbull',
        lastChecked: null,
      ),
    )
    ServiceStatusInfo recoverbull,
    required DateTime lastChecked,
  }) = _AllServicesStatus;

  const AllServicesStatus._();

  bool get allServicesOnline =>
      internetConnection.isOnline &&
      bitcoinElectrum.isOnline &&
      liquidElectrum.isOnline &&
      boltz.isOnline &&
      payjoin.isOnline &&
      pricer.isOnline &&
      mempool.isOnline;

  bool get hasAnyServiceOffline => !allServicesOnline;
}
